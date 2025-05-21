import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'report_page.dart';
import 'package:joyvibe/models/comment.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'figure_profile_page.dart';
import '../utils/vip_check.dart';
import 'vip_page.dart';
import '../utils/coins_check.dart';
import 'wallet_page.dart';

class RecommendPage extends StatefulWidget {
  const RecommendPage({Key? key}) : super(key: key);

  @override
  State<RecommendPage> createState() => RecommendPageState();
}

class RecommendPageState extends State<RecommendPage> {
  List<Map<String, dynamic>> _recommendList = [];
  List<Map<String, dynamic>> _avatarList = [];
  bool _loading = true;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Map<String, VideoPlayerController> _videoControllers = {};
  String? _currentPlayingVideo;
  Set<String> _blockedFigureIds = {};
  Map<int, List<Comment>> _commentsMap = {};
  Set<String> _blockedUserIds = {};
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBlockedList();
    _loadData();
  }

  @override
  void dispose() {
    // 释放所有视频控制器
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeVideo(String videoPath) async {
    if (_videoControllers.containsKey(videoPath)) {
      return;
    }

    final controller = VideoPlayerController.asset(videoPath);
    _videoControllers[videoPath] = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      // 不自动播放，等待用户点击
      await controller.pause();
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _playVideo(String videoPath) {
    if (_currentPlayingVideo != null && _currentPlayingVideo != videoPath) {
      // 暂停其他正在播放的视频
      _videoControllers[_currentPlayingVideo]?.pause();
    }

    final controller = _videoControllers[videoPath];
    if (controller != null) {
      if (controller.value.isPlaying) {
        controller.pause();
        _currentPlayingVideo = null;
      } else {
        controller.play();
        _currentPlayingVideo = videoPath;
      }
    }
  }

  void pauseCurrentVideo() {
    if (_currentPlayingVideo != null) {
      _videoControllers[_currentPlayingVideo]?.pause();
      _currentPlayingVideo = null;
    }
  }

  Future<void> _loadBlockedList() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blockedFigureIds =
          prefs.getStringList('blocked_figure_ids')?.toSet() ?? {};
    });
  }

  Future<void> _saveBlockedList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_figure_ids', _blockedFigureIds.toList());
  }

  Future<void> _showReportSheet(
    BuildContext context,
    Map<String, dynamic> rec,
  ) {
    return showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('What would you like to do?'),
        message: const Text('Choose an action for this content'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => ReportPage(rec: rec)),
              );
            },
            child: const Text('Report'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _blockContent(rec);
            },
            isDestructiveAction: true,
            child: const Text('Block & Hide'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _blockContent(Map<String, dynamic> rec) {
    setState(() {
      _blockedFigureIds.add(rec['figureID'].toString());
      _recommendList.removeWhere(
        (item) => item['figureID'].toString() == rec['figureID'].toString(),
      );
      _avatarList.removeWhere(
        (item) => item['figureID'].toString() == rec['figureID'].toString(),
      );
    });
    _saveBlockedList();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final String jsonStr =
          await rootBundle.loadString('assets/Image/chat/figures.json').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Loading data timed out');
        },
      );

      final List figures = json.decode(jsonStr);
      figures.shuffle(Random());

      // 过滤掉被拉黑的内容
      final List<Map<String, dynamic>> filteredFigures = figures
          .where(
            (figure) =>
                !_blockedFigureIds.contains(figure['figureID'].toString()),
          )
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final List<Map<String, dynamic>> recommendList =
          filteredFigures.take(10).toList();
      final List<Map<String, dynamic>> avatarList =
          List<Map<String, dynamic>>.from(filteredFigures)..shuffle(Random());

      // 加载评论数据
      final String commentsStr = await rootBundle.loadString(
        'assets/Image/chat/comments.json',
      );
      final List commentsJson = json.decode(commentsStr);
      _commentsMap = {};
      for (var c in commentsJson) {
        final comment = Comment.fromJson(c);
        _commentsMap.putIfAbsent(comment.figureID, () => []).add(comment);
      }

      for (var rec in recommendList) {
        final prefs = await SharedPreferences.getInstance();
        rec['like'] =
            prefs.getBool('recommend_like_state_${rec['figureID']}') ?? false;
        rec['likeCount'] =
            prefs.getInt('recommend_like_count_${rec['figureID']}') ??
                (20 + Random().nextInt(10));
        // 评论数直接取真实数据
        rec['commentCount'] = _commentsMap[rec['figureID']]?.length ?? 0;

        await _initializeVideo(rec['figureRecommendVideo']);
      }

      if (mounted) {
        setState(() {
          _recommendList = recommendList;
          _avatarList = avatarList.take(10).toList();
          _loading = false;
          _retryCount = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _retryLoading() {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
      });
      _loadData();
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> rec) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rec['like'] = !(rec['like'] ?? false);
      if (rec['like']) {
        rec['likeCount']++;
      } else {
        rec['likeCount']--;
      }
    });
    await prefs.setBool('recommend_like_state_${rec['figureID']}', rec['like']);
    await prefs.setInt(
      'recommend_like_count_${rec['figureID']}',
      rec['likeCount'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/Image/top_bg_2025_5_16.png',
                    width: screenWidth,
                    fit: BoxFit.cover,
                  ),
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 32, 16, 20),
                        child: Text(
                          'RECOMMEND',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _recommendList.length + 1,
                          separatorBuilder: (_, idx) =>
                              const SizedBox(height: 20),
                          itemBuilder: (context, idx) {
                            if (idx == 1) {
                              return _buildAvatarList();
                            }
                            final rec = idx == 0
                                ? _recommendList[0]
                                : _recommendList[idx - 1];
                            return _buildRecommendCard(rec, screenWidth);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecommendCard(Map<String, dynamic> rec, double screenWidth) {
    final videoController = _videoControllers[rec['figureRecommendVideo']];
    final isCurrentPlaying =
        _currentPlayingVideo == rec['figureRecommendVideo'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // 视频内容+播放/暂停点击
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _playVideo(rec['figureRecommendVideo']);
                        });
                      },
                      child: Container(
                        color: Colors.black12,
                        height: 300,
                        child: videoController?.value.isInitialized == true
                            ? Container(
                                color: Colors.black,
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio:
                                        videoController!.value.aspectRatio,
                                    child: VideoPlayer(videoController),
                                  ),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                      ),
                    ),
                  ),
                ),
                // 左上角头像（带点击跳转）
                Positioned(
                  left: 16,
                  top: 16,
                  child: GestureDetector(
                    onTap: () async {
                      pauseCurrentVideo();
                      final hasPermission = await VipCheck.checkVipPermission(
                          context, VipPermissions.canViewDetails);
                      if (hasPermission) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FigureProfilePage(figure: rec),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: AssetImage(
                              rec['figureRecommendHeaderIcon'],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '@${rec['figureName']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleLike(rec),
                    child: Image.asset(
                      rec['like'] == true
                          ? 'assets/Image/btn_like_2025_5_16_s.png'
                          : 'assets/Image/btn_like_2025_5_16_n.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${rec['likeCount']}',
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showCommentsSheet(context, rec['figureID']),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/Image/btn_message_2025_5_16_n.png',
                          width: 22,
                          height: 22,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rec['commentCount']}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showReportSheet(context, rec),
                    child: Image.asset(
                      'assets/Image/btn_report_2025_5_16_n.png',
                      width: 22,
                      height: 22,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                rec['figureRecommendIntroduce'],
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarList() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _avatarList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final avatar = _avatarList[index];
          return GestureDetector(
            onTap: () async {
              pauseCurrentVideo();
              final hasPermission = await VipCheck.checkVipPermission(
                  context, VipPermissions.canViewDetails);
              if (hasPermission) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FigureProfilePage(figure: avatar),
                  ),
                );
              }
            },
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: AssetImage(
                    avatar['figureRecommendHeaderIcon'],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  avatar['figureName'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, String>> _getCurrentUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString('profile_nickname') ?? 'Anonymous';
    String avatar = prefs.getString('profile_avatar') ??
        'assets/Image/applogo_2025_5_15.png';
    if (!avatar.startsWith('assets/')) {
      final dir = await getApplicationDocumentsDirectory();
      avatar = '${dir.path}/$avatar';
    }
    return {'nickname': nickname, 'avatar': avatar};
  }

  void _blockCommentUser(
    String userID,
    StateSetter setModalState,
    int figureID,
  ) {
    setState(() {
      _blockedUserIds.add(userID);
      _commentsMap[figureID]?.removeWhere((c) => c.userID == userID);
    });
    setModalState(() {});
  }

  void _showCommentReportSheet(
    BuildContext context,
    Comment c,
    StateSetter setModalState,
    int figureID,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('What would you like to do?'),
        message: const Text('Choose an action for this comment'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Report submitted, will be reviewed within 24 hours.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Report'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _blockCommentUser(c.userID, setModalState, figureID);
            },
            isDestructiveAction: true,
            child: const Text('Block & Hide'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context, int figureID) {
    final comments = _commentsMap[figureID] ?? [];
    void addComment(StateSetter setModalState) async {
      final text = _commentController.text.trim();
      if (text.isEmpty) return;

      // 检查是否有足够的coins
      final shouldGoToWallet = await CoinsCheck.checkCoinsForComment(context);
      if (shouldGoToWallet) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const WalletPage()));
        return;
      }
      // 余额足够才继续
      if (_commentController.text.trim().isEmpty) return;
      await CoinsCheck.deductCoinsForComment();

      final userProfile = await _getCurrentUserProfile();
      final newComment = Comment(
        commentID: '${figureID}_${DateTime.now().millisecondsSinceEpoch}',
        figureID: figureID,
        userID: userProfile['nickname'] ?? 'me',
        userName: userProfile['nickname'] ?? 'me',
        userAvatar:
            userProfile['avatar'] ?? 'assets/Image/applogo_2025_5_15.png',
        content: text,
        time: DateTime.now().toString().substring(0, 16),
        likeCount: 0,
        isLiked: false,
      );
      setState(() {
        comments.insert(0, newComment);
        _recommendList.firstWhere(
          (e) => e['figureID'] == figureID,
        )['commentCount'] = comments.length;
      });
      setModalState(() {});
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('评论已提交，需审核后展示给其他用户'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 2 / 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final userProfile = SharedPreferences.getInstance().then(
                  (prefs) => prefs.getString('profile_nickname') ?? 'me',
                );
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              '${comments.length} Comments',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 26),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet. Be the first to comment!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 8,
                              ),
                              itemCount: comments.length,
                              itemBuilder: (context, idx) {
                                final c = comments[idx];
                                if (_blockedUserIds.contains(c.userID))
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundImage:
                                            c.userAvatar.startsWith('assets/')
                                                ? AssetImage(c.userAvatar)
                                                    as ImageProvider
                                                : FileImage(
                                                    File(c.userAvatar),
                                                  ),
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  c.userName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  c.time,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                if (c.userID != null &&
                                                    c.userID !=
                                                        (userProfile is Future
                                                            ? 'me'
                                                            : userProfile))
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _showCommentReportSheet(
                                                      context,
                                                      c,
                                                      setModalState,
                                                      figureID,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        left: 8.0,
                                                      ),
                                                      child: Icon(
                                                        Icons.more_vert,
                                                        size: 18,
                                                        color: Colors.grey[500],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c.content,
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                c.isLiked = !c.isLiked;
                                                c.likeCount +=
                                                    c.isLiked ? 1 : -1;
                                              });
                                            },
                                            child: Icon(
                                              c.isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: c.isLiked
                                                  ? Color(0xFFDB64A5)
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                          Text(
                                            '${c.likeCount}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FA),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 4,
                                ),
                                child: TextField(
                                  controller: _commentController,
                                  decoration: const InputDecoration(
                                    hintText: 'Say something nice~',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDB64A5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => addComment(setModalState),
                              child: const Text(
                                'Send',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCommentDialog(int figureID) async {
    // 直接弹出评论输入框，不做 coins 检查
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_commentController.text.isNotEmpty) {
                // 发送时检测 coins
                final shouldGoToWallet =
                    await CoinsCheck.checkCoinsForComment(context);
                if (shouldGoToWallet) {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletPage()));
                  return;
                }
                await CoinsCheck.deductCoinsForComment();
                setState(() {
                  _commentsMap
                      .putIfAbsent(
                        figureID,
                        () => [],
                      )
                      .add(Comment(
                        commentID:
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        figureID: figureID,
                        userID: 'current_user',
                        userName: 'You',
                        content: _commentController.text,
                        time: DateTime.now().toString().substring(0, 16),
                        userAvatar: 'assets/Image/default_avatar.png',
                        likeCount: 0,
                        isLiked: false,
                      ));
                });
                _commentController.clear();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
