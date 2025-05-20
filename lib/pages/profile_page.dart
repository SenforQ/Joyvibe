import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
    await _initAppDocPath();
    await _loadProfile();
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

  Future<String> _saveAvatarToSandbox(String srcPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}${srcPath.substring(srcPath.lastIndexOf('.'))}';
    final savedPath = '${appDir.path}/$fileName';
    await File(srcPath).copy(savedPath);
    return fileName;
  }

  Future<void> _pickAvatar() async {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7D6F7), Color(0xFFF8F8F8)],
        ),
      ),
      child: SafeArea(
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
                radius: 54,
                backgroundColor: Colors.white,
                child: _avatarFile != null
                    ? CircleAvatar(
                        radius: 50,
                        backgroundImage: FileImage(_avatarFile!),
                      )
                    : CircleAvatar(
                        radius: 50,
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
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B2B3A),
              ),
            ),
            GestureDetector(
              onTap: _editProfile,
              child: const Text(
                'Edit your profile  >',
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
                        leading: const Icon(
                          Icons.group,
                          color: Color(0xFF4B2B3A),
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
                        leading: const Icon(
                          Icons.article,
                          color: Color(0xFF4B2B3A),
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
                        leading: const Icon(
                          Icons.privacy_tip,
                          color: Color(0xFF4B2B3A),
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
