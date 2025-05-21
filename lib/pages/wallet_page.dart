import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

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

Future<void> fetchAndCacheIAPProducts(
    InAppPurchase iap, Set<String> productIds) async {
  final response = await iap.queryProductDetails(productIds);
  if (response.error == null && response.productDetails.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> productList = response.productDetails
        .map((p) => {
              'id': p.id,
              'title': p.title,
              'description': p.description,
              'price': p.price,
              'currencySymbol': p.currencySymbol,
              'rawPrice': p.rawPrice,
            })
        .toList();
    await prefs.setString('iap_product_cache', jsonEncode(productList));
  }
}

Future<List<Map<String, dynamic>>?> getCachedIAPProducts() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString('iap_product_cache');
  if (jsonStr == null) return null;
  final List<dynamic> list = jsonDecode(jsonStr);
  return list.cast<Map<String, dynamic>>();
}

class _WalletProduct {
  final String id;
  final int count;
  final double price;
  const _WalletProduct(this.id, this.count, this.price);
}

// 产品ID常量
class ProductIds {
  static const String coins20 = 'JoyVibe2';
  static const String coins50 = 'JoyVibe5';
  static const String coins100 = 'JoyVibe9';
  static const String coins250 = 'JoyVibe19';
  static const String coins550 = 'JoyVibe49';
  static const String coins1200 = 'JoyVibe99';
  static const String coins1800 = 'JoyVibe159';
  static const String coins2800 = 'JoyVibe239';

  static Set<String> get all => {
        coins20,
        coins50,
        coins100,
        coins250,
        coins550,
        coins1200,
        coins1800,
        coins2800,
      };

  // 获取产品对应的金币数量
  static int getCoinsForProduct(String productId) {
    switch (productId) {
      case coins20:
        return 20;
      case coins50:
        return 50;
      case coins100:
        return 100;
      case coins250:
        return 250;
      case coins550:
        return 550;
      case coins1200:
        return 1200;
      case coins1800:
        return 1800;
      case coins2800:
        return 2800;
      default:
        return 0;
    }
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({Key? key}) : super(key: key);

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  int _balance = 0;
  bool _isLoading = false;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  Map<String, ProductDetails> _products = {};
  int _retryCount = 0;
  static const int maxRetries = 3;

  // 充值档位配置
  final List<_WalletProduct> _productsList = [
    _WalletProduct(ProductIds.coins20, 20, 2.99),
    _WalletProduct(ProductIds.coins50, 50, 5.99),
    _WalletProduct(ProductIds.coins100, 100, 9.99),
    _WalletProduct(ProductIds.coins250, 250, 19.99),
    _WalletProduct(ProductIds.coins550, 550, 49.99),
    _WalletProduct(ProductIds.coins1200, 1200, 99.99),
    _WalletProduct(ProductIds.coins1800, 1800, 159.99),
    _WalletProduct(ProductIds.coins2800, 2800, 239.99),
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _checkConnectivityAndInit();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivityAndInit() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showCenterToast(context,
          'No internet connection. Please check your network settings.');
      return;
    }
    await _initIAP();
  }

  Future<void> _initIAP() async {
    try {
      final available = await _inAppPurchase.isAvailable();
      print('IAP Available: $available');
      if (!mounted) return;
      setState(() {
        _isAvailable = available;
      });
      if (!available) {
        if (mounted) {
          showCenterToast(context, 'In-App Purchase not available');
        }
        return;
      }

      // 获取所有产品ID
      final Set<String> _kIds = ProductIds.all;
      print('Querying products with IDs: $_kIds');

      // 先尝试从缓存获取
      final cachedProducts = await getCachedIAPProducts();
      print('Cached products: $cachedProducts');
      if (cachedProducts != null) {
        setState(() {
          _products = {
            for (var p in cachedProducts)
              p['id']: ProductDetails(
                id: p['id'],
                title: p['title'],
                description: p['description'],
                price: p['price'],
                rawPrice: p['rawPrice'],
                currencySymbol: p['currencySymbol'],
                currencyCode: p['currencyCode'] ?? 'USD',
              )
          };
        });
      }

      // 拉取最新商品信息
      final response = await _inAppPurchase.queryProductDetails(_kIds);
      print('Query response error: ${response.error}');
      print('Found products: ${response.productDetails.length}');
      print('Not found products: ${response.notFoundIDs}');

      if (response.error != null) {
        if (_retryCount < maxRetries) {
          _retryCount++;
          print(
              'Retrying IAP initialization. Attempt $_retryCount of $maxRetries');
          await Future.delayed(Duration(seconds: 2));
          await _initIAP();
          return;
        }
        showCenterToast(
            context, 'Failed to load products: ${response.error!.message}');
      }

      setState(() {
        _products = {for (var p in response.productDetails) p.id: p};
      });
      print('Updated products map: ${_products.keys}');

      // 缓存商品信息
      await fetchAndCacheIAPProducts(_inAppPurchase, _kIds);

      // 监听购买流
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () {
          _subscription?.cancel();
        },
        onError: (e) {
          print('Purchase stream error: $e');
          if (mounted) {
            showCenterToast(context, 'Purchase error: ${e.toString()}');
          }
        },
      );
    } catch (e) {
      print('IAP initialization error: $e');
      if (_retryCount < maxRetries) {
        _retryCount++;
        print(
            'Retrying IAP initialization. Attempt $_retryCount of $maxRetries');
        await Future.delayed(Duration(seconds: 2));
        await _initIAP();
      } else {
        if (mounted) {
          showCenterToast(context,
              'Failed to initialize in-app purchases. Please try again later.');
        }
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _inAppPurchase.completePurchase(purchase);
        // 根据产品ID更新余额
        final product = _products[purchase.productID];
        if (product != null) {
          int coins = _getCoinsForProduct(purchase.productID);
          await _updateBalance(coins);
          showCenterToast(context, 'Successfully purchased $coins coins!');
        }
      } else if (purchase.status == PurchaseStatus.error) {
        showCenterToast(
            context, 'Purchase failed: ${purchase.error?.message ?? ''}');
      } else if (purchase.status == PurchaseStatus.canceled) {
        showCenterToast(context, 'Purchase canceled.');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getCoinsForProduct(String productId) {
    return ProductIds.getCoinsForProduct(productId);
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _balance = prefs.getInt('wallet_balance') ?? 0;
    });
  }

  Future<void> _updateBalance(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = _balance + amount;
    await prefs.setInt('wallet_balance', newBalance);
    setState(() {
      _balance = newBalance;
    });
  }

  Future<void> _handlePurchase(
      String productId, int coins, double price) async {
    if (!_isAvailable) {
      showCenterToast(context, 'Store is not available');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final product = _products[productId];
      print('Attempting to purchase product: $productId');
      print('Product details: $product');

      if (product == null) {
        throw Exception('Product not found');
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      print('Initiating purchase with param: $purchaseParam');
      await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Purchase error: $e');
      if (mounted) {
        showCenterToast(context, 'Purchase failed: ${e.toString()}');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 添加显示说明弹窗的方法
  void _showCoinsExplanation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Image.asset(
              'assets/Image/wallet_coins_2025_5_21.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'About Coins',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B2B3A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Coins are the virtual currency in our app that allow you to:',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF4B2B3A),
              ),
            ),
            SizedBox(height: 16),
            Text(
              '• Leave comments on posts in Explore (5 coins per comment)\n'
              '• Comment on character profiles in Recommend (5 coins per comment)\n'
              '• Interact with other users\n'
              '• Express your appreciation',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Get more coins to enhance your social experience!',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFFDB64A5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFFDB64A5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Wallet',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // 添加感叹号按钮
          IconButton(
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4B2B3A),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Color(0xFF4B2B3A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            onPressed: _showCoinsExplanation,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_balance',
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Coins',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Purchase Coins',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: _productsList
                      .map((product) => _buildPurchaseOption(
                            product.count.toString(),
                            product.price.toStringAsFixed(2),
                            product.id,
                            product.count,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOption(
      String coins, String price, String productId, int coinAmount) {
    final product = _products[productId];
    final isRecommended = productId == ProductIds.coins100;

    return GestureDetector(
      onTap: () => _handlePurchase(productId, coinAmount, double.parse(price)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    coins,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const Text(
                    'Coins',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product?.price ?? '\$$price',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            if (isRecommended)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
