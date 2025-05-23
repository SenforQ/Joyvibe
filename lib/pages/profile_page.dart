import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'wallet_page.dart';
import 'vip_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _avatarPath;
  String? _nickname;
  File? _avatarFile;
  String? _appDocPath;
  int _vipDays = 0;

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
    await _initAppDocPath();
    await _loadProfile();
    await _loadVipStatus();
  }

  Future<void> _initAppDocPath() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _appDocPath = dir.path;
    });
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('profile_avatar');
    final nickname = prefs.getString('profile_nickname');
    if (avatar != null && nickname != null) {
      setState(() {
        _avatarPath = avatar;
        _nickname = nickname;
        if (_avatarPath != null && !_avatarPath!.startsWith('assets/')) {
          _avatarFile = File('${_appDocPath ?? ''}/$_avatarPath');
        }
      });
    } else {
      final ts = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _avatarPath = 'assets/Image/applogo_2025_5_15.png';
        _nickname = 'ID$ts';
        _avatarFile = null;
      });
      await prefs.setString('profile_avatar', _avatarPath!);
      await prefs.setString('profile_nickname', _nickname!);
    }
  }

  Future<void> _loadVipStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vipDays = prefs.getInt(VipPermissions.vipDays) ?? 0;
    });
  }

  Future<String> _saveAvatarToSandbox(String srcPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}${srcPath.substring(srcPath.lastIndexOf('.'))}';
    final savedPath = '${appDir.path}/$fileName';
    await File(srcPath).copy(savedPath);
    return fileName;
  }

  Future<void> _pickAvatar() async {
    // 检查VIP权限
    final hasPermission =
        await VipPermissions.hasVipPermission(VipPermissions.canChangeAvatar);
    if (!hasPermission) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('VIP Required'),
          content: const Text(
              'You need VIP to change your avatar. Would you like to become a VIP?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VipPage()),
                );
              },
              child: const Text('Get VIP'),
            ),
          ],
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final fileName = await _saveAvatarToSandbox(picked.path);
      setState(() {
        _avatarFile = File('${_appDocPath ?? ''}/$fileName');
        _avatarPath = fileName;
      });
    }
  }

  Future<void> _editProfile() async {
    // 检查VIP权限
    final hasPermission =
        await VipPermissions.hasVipPermission(VipPermissions.canChangeAvatar);
    if (!hasPermission) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('VIP Required'),
          content: const Text(
              'You need VIP to change your avatar. Would you like to become a VIP?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VipPage()),
                );
              },
              child: const Text('Get VIP'),
            ),
          ],
        ),
      );
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: _nickname,
    );
    File? tempAvatarFile = _avatarFile;
    String? tempAvatarPath = _avatarPath;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            final fileName = await _saveAvatarToSandbox(
                              picked.path,
                            );
                            setStateDialog(() {
                              tempAvatarFile = File(
                                '${_appDocPath ?? ''}/$fileName',
                              );
                              tempAvatarPath = fileName;
                            });
                          }
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: tempAvatarFile != null
                              ? FileImage(tempAvatarFile!)
                              : AssetImage(
                                  'assets/Image/applogo_2025_5_15.png',
                                ) as ImageProvider,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (picked != null) {
                              final fileName = await _saveAvatarToSandbox(
                                picked.path,
                              );
                              setStateDialog(() {
                                tempAvatarFile = File(
                                  '${_appDocPath ?? ''}/$fileName',
                                );
                                tempAvatarPath = fileName;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.pinkAccent,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'avatar': tempAvatarPath ?? '',
                      'nickname': controller.text,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _avatarPath = result['avatar'];
        _nickname = result['nickname'];
        if (_avatarPath != null && !_avatarPath!.startsWith('assets/')) {
          _avatarFile = File('${_appDocPath ?? ''}/$_avatarPath');
        } else {
          _avatarFile = null;
        }
      });
      await prefs.setString('profile_avatar', _avatarPath!);
      await prefs.setString('profile_nickname', _nickname!);
    }
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF666666), size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF999999),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // 顶部背景图
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/Image/me_top_bg_2025_5_21.png',
              width: screenWidth,
              fit: BoxFit.fitWidth,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: _editProfile,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _editProfile,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: _avatarFile != null
                        ? CircleAvatar(
                            radius: 38,
                            backgroundImage: FileImage(_avatarFile!),
                          )
                        : CircleAvatar(
                            radius: 38,
                            backgroundImage: AssetImage(
                              'assets/Image/applogo_2025_5_15.png',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _nickname ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                GestureDetector(
                  onTap: _editProfile,
                  child: const Text(
                    'Edit your profile  >',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Vip Club 和 My Wallet 入口
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const VipPage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/Image/me_vip_2025_5_21.png',
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Vip Club',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4B2B3A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const WalletPage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/Image/me_wallet_2025_5_21.png',
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'My Wallet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4B2B3A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Features',
                      style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: ListView(
                        children: [
                          ListTile(
                            leading: Image.asset(
                              'assets/Image/me_about_2025_5_21.png',
                              width: 24,
                              height: 24,
                            ),
                            title: const Text(
                              'About us',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B2B3A),
                                fontSize: 16,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, '/about');
                            },
                          ),
                          ListTile(
                            leading: Image.asset(
                              'assets/Image/me_user_2025_5_21.png',
                              width: 24,
                              height: 24,
                            ),
                            title: const Text(
                              'User Contract',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B2B3A),
                                fontSize: 16,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, '/terms');
                            },
                          ),
                          ListTile(
                            leading: Image.asset(
                              'assets/Image/me_privacy_2025_5_51.png',
                              width: 24,
                              height: 24,
                            ),
                            title: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B2B3A),
                                fontSize: 16,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, '/privacy');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 36),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF4B2B3A),
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureIcon(IconData icon, String title) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.pinkAccent.withOpacity(0.08),
          child: Icon(icon, color: const Color(0xFF4B2B3A), size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B2B3A),
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
