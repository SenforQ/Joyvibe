import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

// VIP产品ID常量
class VipProductIds {
  static const String week = 'JoyVibeWeekVIP';
  static const String month = 'JoyVibeMonthVIP';
  static Set<String> get all => {week, month};
}

// VIP权限常量
class VipPermissions {
  static const String canChangeAvatar = 'vip_can_change_avatar';
  static const String canViewDetails = 'vip_can_view_details';
  static const String canWatchVideos = 'vip_can_watch_videos';
  static const String vipDays = 'vip_days';

  // 检查VIP权限
  static Future<bool> hasVipPermission(String permission) async {
    final prefs = await SharedPreferences.getInstance();
    final vipDays = prefs.getInt(VipPermissions.vipDays) ?? 0;
    if (vipDays <= 0) return false;
    return prefs.getBool(permission) ?? false;
  }
}

class VipPage extends StatefulWidget {
  const VipPage({Key? key}) : super(key: key);

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  int _selectedIndex = 0; // 0: 周订阅, 1: 月订阅
  bool _isLoading = false;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  Map<String, ProductDetails> _products = {};
  int _retryCount = 0;
  static const int maxRetries = 3;
  static const String weekProductId = VipProductIds.week;
  static const String monthProductId = VipProductIds.month;
  static const double weekPrice = 12.99;
  static const double monthPrice = 49.99;
  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndInit();
    _subscription = _inAppPurchase.purchaseStream.listen(_onPurchaseUpdate);
    _restorePurchases();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivityAndInit() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showToast('No internet connection. Please check your network settings.');
      return;
    }
    await _initIAP();
  }

  Future<void> _initIAP() async {
    try {
      final available = await _inAppPurchase.isAvailable();
      setState(() {
        _isAvailable = available;
      });
      if (!available) {
        _showToast('In-App Purchase not available');
        return;
      }

      final response =
          await _inAppPurchase.queryProductDetails(VipProductIds.all);
      if (response.error != null) {
        if (_retryCount < maxRetries) {
          _retryCount++;
          await Future.delayed(Duration(seconds: 2));
          await _initIAP();
          return;
        }
        _showToast('Failed to load products: ${response.error!.message}');
      }

      setState(() {
        _products = {for (var p in response.productDetails) p.id: p};
      });

      _subscription =
          _inAppPurchase.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
        _subscription.cancel();
      }, onError: (e) {
        _showToast('Purchase error: ${e.toString()}');
      });
    } catch (e) {
      if (_retryCount < maxRetries) {
        _retryCount++;
        await Future.delayed(Duration(seconds: 2));
        await _initIAP();
      } else {
        _showToast(
            'Failed to initialize in-app purchases. Please try again later.');
      }
    }
  }

  // 更新VIP权限
  Future<void> _updateVipPermissions(int days) async {
    final prefs = await SharedPreferences.getInstance();
    // 更新VIP天数
    await prefs.setInt(VipPermissions.vipDays, days);
    // 设置所有VIP权限为true
    await prefs.setBool(VipPermissions.canChangeAvatar, true);
    await prefs.setBool(VipPermissions.canViewDetails, true);
    await prefs.setBool(VipPermissions.canWatchVideos, true);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // 处理取消状态
      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await showCenterToast(context, 'Purchase canceled.');
        }
        return;
      }

      // 处理购买成功状态
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _inAppPurchase.completePurchase(purchase);
        int addDays = _selectedIndex == 0 ? 7 : 30; // 修改为实际购买天数，不再赠送
        final prefs = await SharedPreferences.getInstance();
        int currentVip = prefs.getInt(VipPermissions.vipDays) ?? 0;
        int newVipDays = currentVip + addDays;

        // 更新VIP权限
        await _updateVipPermissions(newVipDays);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await showCenterToast(context, 'VIP activated! +$addDays days');
        }
        return;
      }

      // 处理错误状态
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await showCenterToast(
              context, 'Purchase failed: ' + (purchase.error?.message ?? ''));
        }
        return;
      }
    }
  }

  void _onConfirm() async {
    if (_isLoading) return; // 防止重复点击

    setState(() {
      _isLoading = true;
    });

    final productId = _selectedIndex == 0 ? weekProductId : monthProductId;
    final response = await _inAppPurchase.queryProductDetails({productId});

    if (response.productDetails.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      await showCenterToast(context, 'Product not found.');
      return;
    }

    final product = response.productDetails.first;
    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await showCenterToast(context, 'Failed to initiate purchase.');
      }
    }
  }

  void _showToast(String message) async {
    await showCenterToast(context, message);
  }

  // 添加恢复购买方法
  Future<void> _restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // 恢复购买的结果会通过 purchaseStream 传递到 _onPurchaseUpdate
    } catch (e) {
      if (mounted) {
        await showCenterToast(
            context, 'Failed to restore purchases: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 顶部背景图片
                Stack(
                  children: [
                    Image.asset(
                      'assets/Image/vip_top_bg_2025_5_21.png',
                      width: screenWidth,
                      fit: BoxFit.cover,
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 8),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 内容整体上移50px
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildSubscribeButton(
                              price: weekPrice.toStringAsFixed(2),
                              label: 'Per week',
                              selected: _selectedIndex == 0,
                              onTap: () => setState(() => _selectedIndex = 0),
                            ),
                            const SizedBox(width: 16),
                            _buildSubscribeButton(
                              price: monthPrice.toStringAsFixed(2),
                              label: 'Per month',
                              selected: _selectedIndex == 1,
                              onTap: () => setState(() => _selectedIndex = 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _isLoading ? null : _onConfirm,
                        child: Image.asset(
                          'assets/Image/vip_confirm_2025_5_21.png',
                          width: screenWidth - 48,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: Image.asset(
                          'assets/Image/vip_exclusive_2025_5_21.png',
                          width: 255,
                          height: 21,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 新增：VIP特权说明
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            _PrivilegeItem(
                              image: 'assets/Image/vip_avatar_2025_5_21.png',
                              title: 'Unlimited avatar changes',
                              subtitle:
                                  'VIPs can change avatars without limits',
                            ),
                            const SizedBox(height: 20),
                            _PrivilegeItem(
                              image: 'assets/Image/vip_video_2025_5_21.png',
                              title: 'Unlimited video viewing',
                              subtitle: 'VIP can watch videos unlimited times',
                            ),
                            if (_selectedIndex == 1) ...[
                              const SizedBox(height: 20),
                              _PrivilegeItem(
                                image: 'assets/Image/vip_user_2025_5_21.png',
                                title: 'Unlimited Avatar list views',
                                subtitle:
                                    'VIPs can view avatar lists endlessly',
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 添加底部文字和恢复购买按钮
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: _restorePurchases,
                              child: const Text(
                                'Restore Purchase',
                                style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/privacy');
                                  },
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' and ',
                                  style: TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/terms');
                                  },
                                  child: const Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(
      {required String price,
      required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF8E1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFFFFC107) : Colors.grey.shade200,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'USD $price',
                style: TextStyle(
                  color: selected ? const Color(0xFFFFC107) : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFC107) : Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total $price',
                style: TextStyle(
                  color: selected ? const Color(0xFFFFC107) : Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 新增说明项组件
class _PrivilegeItem extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  const _PrivilegeItem({
    required this.image,
    required this.title,
    required this.subtitle,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(image, width: 36, height: 36, fit: BoxFit.contain),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 居中自动消失提示
Future<void> showCenterToast(BuildContext context, String message,
    {int milliseconds = 1800}) async {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(opacity: anim1, child: child);
    },
  );
  await Future.delayed(Duration(milliseconds: milliseconds));
  if (Navigator.of(context, rootNavigator: true).canPop()) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
