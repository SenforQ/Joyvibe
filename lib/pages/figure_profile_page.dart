import 'package:flutter/material.dart';
import 'dart:math';
import 'role_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FigureProfilePage extends StatefulWidget {
  final Map<String, dynamic> figure;
  const FigureProfilePage({Key? key, required this.figure}) : super(key: key);

  @override
  State<FigureProfilePage> createState() => _FigureProfilePageState();
}

class _FigureProfilePageState extends State<FigureProfilePage> {
  bool _isFollowed = false;
  Set<String> _followedIds = {};

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('followed_role_ids') ?? [];
    setState(() {
      _followedIds = ids.toSet();
      _isFollowed = _followedIds.contains(widget.figure['figureID'].toString());
    });
  }

  Future<void> _toggleFollow() async {
    final prefs = await SharedPreferences.getInstance();
    final id = widget.figure['figureID'].toString();
    setState(() {
      if (_isFollowed) {
        _followedIds.remove(id);
        _isFollowed = false;
      } else {
        _followedIds.add(id);
        _isFollowed = true;
      }
    });
    await prefs.setStringList('followed_role_ids', _followedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> photos = widget.figure['figurePhotoArray'] ?? [];
    final String topPhoto =
        (photos.isNotEmpty) ? (photos[Random().nextInt(photos.length)]) : '';
    final String avatar = widget.figure['figureRecommendHeaderIcon'] ?? '';
    final String name = widget.figure['figureName'] ?? '';
    final String intro = widget.figure['figureRecommendIntroduce'] ?? '';
    final double screenWidth = MediaQuery.of(context).size.width;
    final double topImageHeight = 260;
    final double avatarRadius = 54;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 120), // 给底部按钮留空间
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // 顶部大图
                    if (topPhoto.isNotEmpty)
                      Image.asset(
                        topPhoto,
                        width: screenWidth,
                        height: topImageHeight,
                        fit: BoxFit.cover,
                      ),
                    // 返回按钮（不使用SafeArea，直接贴顶）
                    Positioned(
                      left: 8,
                      top: 16, // 直接贴近屏幕顶部
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                // 头像悬浮在大图下方
                Transform.translate(
                  offset: Offset(0, -avatarRadius),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: avatarRadius - 4,
                      backgroundImage: AssetImage(avatar),
                    ),
                  ),
                ),
                // 昵称紧跟头像下方
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B2B3A),
                  ),
                ),
                const SizedBox(height: 8),
                // 个人介绍（最大7行，超出...）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    intro,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 28),
                // 占位，按钮区用Stack底部实现
              ],
            ),
          ),
          // 底部按钮区
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFollowed ? Colors.white : const Color(0xFFDB64A5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            _isFollowed
                                ? const BorderSide(
                                  color: Color(0xFFDB64A5),
                                  width: 2,
                                )
                                : BorderSide.none,
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isFollowed ? 'Unfollow' : 'Follow',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            _isFollowed
                                ? const Color(0xFFDB64A5)
                                : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoleChatPage(figure: widget.figure),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFDB64A5),
                          width: 2,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFDB64A5),
                        fontWeight: FontWeight.bold,
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
}
