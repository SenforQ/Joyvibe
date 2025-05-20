import 'package:flutter/material.dart';
import 'recommend_page.dart';
import 'profile_page.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_chat_page.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'figure_profile_page.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'report_page.dart';

// 1. 定义图片点赞/评论/举报本地状态
class _ImageActionState {
  bool liked;
  int likeCount;
  int commentCount;
  _ImageActionState({
    this.liked = false,
    this.likeCount = 0,
    this.commentCount = 0,
  });
}

// 1. 评论数据结构
class _Comment {
  final String userID;
  final String content;
  int likeCount;
  bool isLiked;
  _Comment({
    required this.userID,
    required this.content,
    this.likeCount = 0,
    this.isLiked = false,
  });
}

// ======= 新 ExplorePage 实现 =======
class ExplorePage extends StatefulWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final List<_TagInfo> _allTags = [
    _TagInfo('weekend', 'Weekend', 'assets/Image/weekend_2025_5_19.png'),
    _TagInfo(
      'afternoonTea',
      'Afternoon Tea',
      'assets/Image/afternoonTea_2025_5_19.png',
    ),
    _TagInfo('surf', 'Surf', 'assets/Image/surf_2025_5_19.png'),
    _TagInfo('selfie', 'Selfie', 'assets/Image/selfie_2025_5_19.png'),
  ];
  List<Map<String, dynamic>> _allFigures = [];
  List<_ExplorePost> _allPosts = [];
  Map<String, int> _tagCount = {};
  String _selectedTag = 'weekend';
  bool _loading = true;
  Set<String> _followedIds = {};
  final Map<String, _ImageActionState> _imageActionMap = {};
  Set<String> _blockedIds = {};
  final Map<String, List<_Comment>> _commentsMap = {};
  final String _currentUserId = 'me'; // 本地模拟当前用户ID
  String _currentUserAvatar = 'assets/Image/applogo_2025_5_15.png';
  String _currentUserNickname = 'Me';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 加载角色
    final String jsonStr = await rootBundle.loadString(
      'assets/Image/chat/figures.json',
    );
    final List figuresList = json.decode(jsonStr);
    _allFigures = List<Map<String, dynamic>>.from(figuresList);
    // 加载关注状态
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('followed_role_ids') ?? [];
    _followedIds = ids.toSet();
    // 加载拉黑ID
    final blockedIds = prefs.getStringList('blocked_figure_ids')?.toSet() ?? {};
    _blockedIds = blockedIds;
    // 生成mock文案并过滤拉黑
    _allPosts = _generateMockPosts(_allFigures, _allTags, 40, _blockedIds);
    // 统计标签数量
    _tagCount = {};
    for (var tag in _allTags) {
      _tagCount[tag.key] =
          _allPosts.where((p) => p.tags.contains(tag.key)).length;
    }
    // 默认选中第一个有内容的标签
    _selectedTag =
        _allTags
            .firstWhere((t) => _tagCount[t.key]! > 0, orElse: () => _allTags[0])
            .key;
    setState(() {
      _loading = false;
    });
    // 生成视频缩略图
    await _generateAllVideoThumbnails();
    // 获取本地用户头像和昵称
    final nickname = prefs.getString('profile_nickname') ?? 'Me';
    String avatar =
        prefs.getString('profile_avatar') ??
        'assets/Image/applogo_2025_5_15.png';
    if (!avatar.startsWith('assets/')) {
      final dir = await getApplicationDocumentsDirectory();
      avatar = '${dir.path}/$avatar';
    }
    _currentUserNickname = nickname;
    _currentUserAvatar = avatar;
  }

  Future<void> _generateAllVideoThumbnails() async {
    for (var post in _allPosts) {
      if (post.video != null && post.videoCoverBytes == null) {
        try {
          final tempPath = await _copyAssetToTemp(post.video!);
          final bytes = await VideoThumbnail.thumbnailData(
            video: tempPath,
            imageFormat: ImageFormat.PNG,
            maxWidth: 320,
            quality: 75,
          );
          if (bytes != null) {
            setState(() {
              post.videoCoverBytes = bytes;
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<String> _copyAssetToTemp(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${assetPath.split('/').last}');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return tempFile.path;
  }

  Future<void> _blockContent(Map<String, dynamic> figure) async {
    final prefs = await SharedPreferences.getInstance();
    final blockedIds = prefs.getStringList('blocked_figure_ids')?.toSet() ?? {};
    blockedIds.add(figure['figureID'].toString());
    await prefs.setStringList('blocked_figure_ids', blockedIds.toList());
    await _initData(); // 拉黑后重新生成并过滤
  }

  List<_ExplorePost> _generateMockPosts(
    List<Map<String, dynamic>> figures,
    List<_TagInfo> tags,
    int count,
    Set<String> blockedIds,
  ) {
    final List<String> sampleTexts = [
      "Enjoying a healthy lifestyle!",
      "Let's go surfing together!",
      "Wishing you a wonderful weekend!",
      "A picnic is also a new experience.",
      "Life is beautiful, cherish every moment.",
      "Exploring new places brings joy.",
      "Design makes life better.",
      "Animals are our friends.",
      "Tourism opens your mind.",
      "Water rafting is so exciting!",
      "Stay positive and keep smiling!",
      "Let's have fun this weekend!",
      "Invite you to join my journey!",
      "Healthy food, healthy mood.",
      "Let's enjoy the sunshine!",
      "Friends make life colorful.",
      "A new adventure awaits!",
      "Let's create memories together.",
      "Nature heals the soul.",
      "Keep moving forward!",
    ];
    final rand = Random();
    final List<_ExplorePost> posts = [];
    // 确保每个角色至少一条
    for (var figure in figures) {
      if (blockedIds.contains(figure['figureID'].toString())) continue;
      final tag = tags[rand.nextInt(tags.length)].key;
      final hasVideo =
          (figure['figureVideoArray'] ?? []).isNotEmpty && rand.nextBool();
      final images = hasVideo ? <String>[] : _pickRandomImages(figure, rand);
      final video = hasVideo ? _pickRandomVideo(figure, rand) : null;
      posts.add(
        _ExplorePost(
          id: UniqueKey().toString(),
          figure: figure,
          content: sampleTexts[rand.nextInt(sampleTexts.length)],
          images: images,
          video: video,
          time: DateTime.now().subtract(
            Duration(hours: rand.nextInt(48), minutes: rand.nextInt(60)),
          ),
          tags: [tag],
        ),
      );
    }
    // 其余随机生成
    for (int i = posts.length; i < count; i++) {
      final figure = figures[rand.nextInt(figures.length)];
      if (blockedIds.contains(figure['figureID'].toString())) continue;
      final tag = tags[rand.nextInt(tags.length)].key;
      final hasVideo =
          (figure['figureVideoArray'] ?? []).isNotEmpty && rand.nextBool();
      final images = hasVideo ? <String>[] : _pickRandomImages(figure, rand);
      final video = hasVideo ? _pickRandomVideo(figure, rand) : null;
      posts.add(
        _ExplorePost(
          id: UniqueKey().toString(),
          figure: figure,
          content: sampleTexts[rand.nextInt(sampleTexts.length)],
          images: images,
          video: video,
          time: DateTime.now().subtract(
            Duration(hours: rand.nextInt(48), minutes: rand.nextInt(60)),
          ),
          tags: [tag],
        ),
      );
    }
    // 按时间从新到旧排序
    posts.sort((a, b) => b.time.compareTo(a.time));
    return posts;
  }

  static List<String> _pickRandomImages(
    Map<String, dynamic> figure,
    Random rand,
  ) {
    final List<dynamic> imgs = figure['figurePhotoArray'] ?? [];
    if (imgs.isEmpty) return [];
    final count = 1 + rand.nextInt(2); // 1~2张
    final shuffled = List<String>.from(imgs.map((img) => img.toString()));
    return shuffled.take(count).toList();
  }

  static String? _pickRandomVideo(Map<String, dynamic> figure, Random rand) {
    final List<dynamic> vids = figure['figureVideoArray'] ?? [];
    if (vids.isEmpty) return null;
    return vids[rand.nextInt(vids.length)];
  }

  void _toggleFollow(String figureId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_followedIds.contains(figureId)) {
        _followedIds.remove(figureId);
      } else {
        _followedIds.add(figureId);
      }
    });
    await prefs.setStringList('followed_role_ids', _followedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final double topBgHeight = 180;
    final double cardRadius = 20;
    final double avatarSize = 44;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double tagItemWidth = (screenWidth - 30 - 15) / 2.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Stack(
        children: [
          // 顶部背景
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/Image/top_bg_2025_5_16.png',
              width: screenWidth,
              height: topBgHeight,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'EXPLORE',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1A2F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // 标签栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: tagItemWidth / 64,
                    ),
                    itemCount: _allTags.length,
                    itemBuilder: (context, idx) {
                      final tag = _allTags[idx];
                      return GestureDetector(
                        onTap: () {
                          final posts =
                              _allPosts
                                  .where((p) => p.tags.contains(tag.key))
                                  .toList();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => TagExplorePage(
                                    tagLabel: tag.label,
                                    posts: posts,
                                    avatarSize: avatarSize,
                                    followedIds: _followedIds,
                                    onToggleFollow: _toggleFollow,
                                    commentsMap: _commentsMap,
                                    currentUserId: _currentUserId,
                                    currentUserAvatar: _currentUserAvatar,
                                    currentUserNickname: _currentUserNickname,
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          width: tagItemWidth,
                          height: 64,
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  tag.icon,
                                  width: 42,
                                  height: 42,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${tag.label}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF2B1A2F),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_tagCount[tag.key] ?? 0} used',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 内容卡片
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: Container(
                        color: Colors.white,
                        child:
                            _loading
                                ? Center(child: CircularProgressIndicator())
                                : ListView.separated(
                                  padding: const EdgeInsets.only(
                                    top: 15,
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                  ),
                                  itemCount: _allPosts.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 15),
                                  itemBuilder: (context, idx) {
                                    final post = _allPosts[idx];
                                    final figure = post.figure;
                                    final isFollowed = _followedIds.contains(
                                      figure['figureID'].toString(),
                                    );
                                    return Column(
                                      children: [
                                        SizedBox(
                                          height: 244,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 0,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: avatarSize / 2,
                                                      backgroundImage: AssetImage(
                                                        figure['figureRecommendHeaderIcon'] ??
                                                            'assets/Image/applogo_2025_5_15.png',
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          figure['figureName'] ??
                                                              '',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 18,
                                                                color: Color(
                                                                  0xFF2B1A2F,
                                                                ),
                                                              ),
                                                        ),
                                                        Text(
                                                          _formatTimeSmart(
                                                            post.time,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color: Color(
                                                                  0xFF888888,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const Spacer(),
                                                    _buildFollowButton(
                                                      isFollowed,
                                                      figure['figureID']
                                                          .toString(),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  post.content,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF2B1A2F),
                                                  ),
                                                ),
                                                if (post.images.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Row(
                                                      children:
                                                          post.images.map((
                                                            img,
                                                          ) {
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).push(
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (
                                                                            _,
                                                                          ) => FullScreenImageViewer(
                                                                            imagePath:
                                                                                img,
                                                                          ),
                                                                    ),
                                                                  );
                                                                },
                                                                child: ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  child: Image.asset(
                                                                    img,
                                                                    width: 100,
                                                                    height: 100,
                                                                    fit:
                                                                        BoxFit
                                                                            .cover,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                    ),
                                                  ),
                                                if (post.video != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        Navigator.of(
                                                          context,
                                                        ).push(
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  _,
                                                                ) => FullScreenVideoPlayer(
                                                                  videoPath:
                                                                      post.video!,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                      child: Stack(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            child: Container(
                                                              width: 160,
                                                              height: 96,
                                                              color:
                                                                  Colors
                                                                      .black12,
                                                              child:
                                                                  post.videoCoverBytes !=
                                                                          null
                                                                      ? Image.memory(
                                                                        post.videoCoverBytes!,
                                                                        width:
                                                                            160,
                                                                        height:
                                                                            96,
                                                                        fit:
                                                                            BoxFit.cover,
                                                                      )
                                                                      : Center(
                                                                        child: SizedBox(
                                                                          width:
                                                                              32,
                                                                          height:
                                                                              32,
                                                                          child: CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2,
                                                                          ),
                                                                        ),
                                                                      ),
                                                            ),
                                                          ),
                                                          Positioned.fill(
                                                            child: Center(
                                                              child: Icon(
                                                                Icons
                                                                    .play_circle_fill,
                                                                color: Color(
                                                                  0xFFB16CEA,
                                                                ),
                                                                size: 48,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                // 20px空白
                                                const SizedBox(height: 20),
                                                // 操作按钮区域
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                      ),
                                                  child: StatefulBuilder(
                                                    builder: (
                                                      context,
                                                      setModalState,
                                                    ) {
                                                      final String contentId =
                                                          post.images.isNotEmpty
                                                              ? post.images[0]
                                                              : (post.video ??
                                                                  '');
                                                      final action = _imageActionMap
                                                          .putIfAbsent(
                                                            contentId,
                                                            () =>
                                                                _ImageActionState(
                                                                  likeCount: 20,
                                                                  commentCount:
                                                                      5,
                                                                ),
                                                          );
                                                      return Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          // 左侧举报按钮
                                                          GestureDetector(
                                                            onTap:
                                                                () => _showImageReportSheet(
                                                                  context,
                                                                  post.figure,
                                                                  contentId,
                                                                ),
                                                            child: Image.asset(
                                                              'assets/Image/btn_report_2025_5_16_n.png',
                                                              width: 24,
                                                              height: 24,
                                                            ),
                                                          ),
                                                          // 右侧点赞和评论按钮组
                                                          Row(
                                                            children: [
                                                              GestureDetector(
                                                                onTap: () {
                                                                  setModalState(() {
                                                                    action.liked =
                                                                        !action
                                                                            .liked;
                                                                    action.likeCount +=
                                                                        action.liked
                                                                            ? 1
                                                                            : -1;
                                                                  });
                                                                },
                                                                child: Row(
                                                                  children: [
                                                                    Image.asset(
                                                                      action.liked
                                                                          ? 'assets/Image/btn_like_2025_5_16_s.png'
                                                                          : 'assets/Image/btn_like_2025_5_16_n.png',
                                                                      width: 24,
                                                                      height:
                                                                          24,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 7,
                                                                    ),
                                                                    Text(
                                                                      '${action.likeCount}',
                                                                      style: const TextStyle(
                                                                        color: Color(
                                                                          0xFF999999,
                                                                        ),
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 34,
                                                              ),
                                                              GestureDetector(
                                                                onTap:
                                                                    () => _showImageCommentSheet(
                                                                      context,
                                                                      contentId,
                                                                      action,
                                                                    ),
                                                                child: Row(
                                                                  children: [
                                                                    Image.asset(
                                                                      'assets/Image/btn_message_2025_5_16_n.png',
                                                                      width: 22,
                                                                      height:
                                                                          22,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 7,
                                                                    ),
                                                                    Text(
                                                                      '${_commentsMap[contentId]?.length ?? 0}',
                                                                      style: const TextStyle(
                                                                        color: Color(
                                                                          0xFF999999,
                                                                        ),
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // 20px空白
                                        // const SizedBox(height: 20),
                                        // 分割线
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 15,
                                          ),
                                          child: Container(
                                            height: 1,
                                            color: Color(0xFFF5F7F9),
                                          ),
                                        ),
                                        // 23px空白
                                        const SizedBox(height: 23),
                                      ],
                                    );
                                  },
                                ),
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

  Widget _buildFollowButton(bool isFollowed, String figureId) {
    return GestureDetector(
      onTap: () => _toggleFollow(figureId),
      child: Container(
        width: 90,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient:
              isFollowed
                  ? null
                  : const LinearGradient(
                    colors: [Color(0xFF69ACFF), Color(0xFFFF84FD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          color: isFollowed ? const Color(0xFFE0E0E0) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          isFollowed ? 'Followed' : 'Follow',
          style: TextStyle(
            color: isFollowed ? Color(0xFF888888) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _formatTimeSmart(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  // 举报弹窗
  void _showImageReportSheet(
    BuildContext context,
    Map<String, dynamic> figure,
    String img,
  ) async {
    showCupertinoModalPopup(
      context: context,
      builder:
          (BuildContext context) => CupertinoActionSheet(
            title: const Text('What would you like to do?'),
            message: const Text('Choose an action for this content'),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => ReportPage(rec: figure)),
                  );
                },
                child: const Text('Report'),
              ),
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  await _blockContent(figure);
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

  Future<void> _refreshCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString('profile_nickname') ?? 'Me';
    String avatar =
        prefs.getString('profile_avatar') ??
        'assets/Image/applogo_2025_5_15.png';
    if (!avatar.startsWith('assets/')) {
      final dir = await getApplicationDocumentsDirectory();
      avatar = '${dir.path}/$avatar';
    }
    setState(() {
      _currentUserNickname = nickname;
      _currentUserAvatar = avatar;
    });
  }

  // 评论弹窗
  void _showImageCommentSheet(
    BuildContext context,
    String contentId,
    _ImageActionState action,
  ) async {
    await _refreshCurrentUserInfo();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final comments = _commentsMap.putIfAbsent(contentId, () => []);
            final TextEditingController _commentController =
                TextEditingController();
            final userComments =
                comments.where((c) => c.userID == _currentUserId).toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Comments',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(),
                  SizedBox(
                    height: 220,
                    child:
                        userComments.isEmpty
                            ? const Center(child: Text('No comments yet.'))
                            : ListView.separated(
                              itemCount: userComments.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final c = userComments[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: AssetImage(
                                      _currentUserAvatar,
                                    ),
                                    radius: 20,
                                  ),
                                  title: Text(_currentUserNickname),
                                  subtitle: Text(c.content),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            c.isLiked = !c.isLiked;
                                            c.likeCount += c.isLiked ? 1 : -1;
                                          });
                                        },
                                        child: Icon(
                                          c.isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color:
                                              c.isLiked
                                                  ? Color(0xFFDB64A5)
                                                  : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${c.likeCount}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFFB16CEA),
                          ),
                          onPressed: () {
                            final text = _commentController.text.trim();
                            if (text.isNotEmpty) {
                              setModalState(() {
                                comments.add(
                                  _Comment(
                                    userID: _currentUserId,
                                    content: text,
                                    likeCount: 0,
                                  ),
                                );
                                action.commentCount =
                                    comments
                                        .where(
                                          (c) => c.userID == _currentUserId,
                                        )
                                        .length;
                                _commentController.clear();
                              });
                              // 刷新主页面评论数
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ExplorePost {
  final String id;
  final Map<String, dynamic> figure;
  final String content;
  final List<String> images;
  final String? video;
  final DateTime time;
  final List<String> tags;
  Uint8List? videoCoverBytes;
  _ExplorePost({
    required this.id,
    required this.figure,
    required this.content,
    required this.images,
    required this.video,
    required this.time,
    required this.tags,
    this.videoCoverBytes,
  });
}

// 新增标签信息类
class _TagInfo {
  final String key;
  final String label;
  final String icon;
  const _TagInfo(this.key, this.label, this.icon);
}

// 标签详情页
class TagExplorePage extends StatefulWidget {
  final String tagLabel;
  final List<_ExplorePost> posts;
  final double avatarSize;
  final Set<String> followedIds;
  final void Function(String) onToggleFollow;
  final Map<String, List<_Comment>> commentsMap;
  final String currentUserId;
  final String currentUserAvatar;
  final String currentUserNickname;
  TagExplorePage({
    Key? key,
    required this.tagLabel,
    required this.posts,
    required this.avatarSize,
    required this.followedIds,
    required this.onToggleFollow,
    required this.commentsMap,
    required this.currentUserId,
    required this.currentUserAvatar,
    required this.currentUserNickname,
  }) : super(key: key);

  @override
  State<TagExplorePage> createState() => _TagExplorePageState();
}

class _TagExplorePageState extends State<TagExplorePage> {
  List<_ExplorePost> _filteredPosts = [];
  Set<String> _blockedIds = {};
  final Map<String, int> _likeCountMap = {};
  final Map<String, _ImageActionState> _actionMap = {};

  @override
  void initState() {
    super.initState();
    _loadBlockedIdsAndFilter();
  }

  Future<void> _loadBlockedIdsAndFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedIds = prefs.getStringList('blocked_figure_ids')?.toSet() ?? {};
    final filtered =
        widget.posts
            .where((p) => !blockedIds.contains(p.figure['figureID'].toString()))
            .toList();
    // 为每条内容初始化随机点赞数（0~20）
    final rand = Random();
    for (var post in filtered) {
      final contentId =
          post.images.isNotEmpty ? post.images[0] : (post.video ?? '');
      _likeCountMap[contentId] = rand.nextInt(21); // 0~20
    }
    setState(() {
      _blockedIds = blockedIds;
      _filteredPosts = filtered;
    });
  }

  Future<void> _blockContent(Map<String, dynamic> figure) async {
    final prefs = await SharedPreferences.getInstance();
    final blockedIds = prefs.getStringList('blocked_figure_ids')?.toSet() ?? {};
    blockedIds.add(figure['figureID'].toString());
    await prefs.setStringList('blocked_figure_ids', blockedIds.toList());
    await _loadBlockedIdsAndFilter();
  }

  void _showImageReportSheet(
    BuildContext context,
    Map<String, dynamic> figure,
    String img,
  ) async {
    showCupertinoModalPopup(
      context: context,
      builder:
          (BuildContext context) => CupertinoActionSheet(
            title: const Text('What would you like to do?'),
            message: const Text('Choose an action for this content'),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => ReportPage(rec: figure)),
                  );
                },
                child: const Text('Report'),
              ),
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  await _blockContent(figure);
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

  void _showImageCommentSheet(
    BuildContext context,
    String contentId,
    _ImageActionState action,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final comments = widget.commentsMap.putIfAbsent(
              contentId,
              () => [],
            );
            final TextEditingController _commentController =
                TextEditingController();
            final userComments =
                comments
                    .where((c) => c.userID == widget.currentUserId)
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Comments',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(),
                  SizedBox(
                    height: 220,
                    child:
                        userComments.isEmpty
                            ? const Center(child: Text('No comments yet.'))
                            : ListView.separated(
                              itemCount: userComments.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final c = userComments[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: AssetImage(
                                      widget.currentUserAvatar,
                                    ),
                                    radius: 20,
                                  ),
                                  title: Text(widget.currentUserNickname),
                                  subtitle: Text(c.content),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            c.isLiked = !c.isLiked;
                                            c.likeCount += c.isLiked ? 1 : -1;
                                          });
                                        },
                                        child: Icon(
                                          c.isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color:
                                              c.isLiked
                                                  ? Color(0xFFDB64A5)
                                                  : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${c.likeCount}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFFB16CEA),
                          ),
                          onPressed: () {
                            final text = _commentController.text.trim();
                            if (text.isNotEmpty) {
                              setModalState(() {
                                comments.add(
                                  _Comment(
                                    userID: widget.currentUserId,
                                    content: text,
                                    likeCount: 0,
                                  ),
                                );
                                action.commentCount =
                                    comments
                                        .where(
                                          (c) =>
                                              c.userID == widget.currentUserId,
                                        )
                                        .length;
                                _commentController.clear();
                              });
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimeSmart(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.tagLabel,
          style: const TextStyle(
            color: Color(0xFF2B1A2F),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2B1A2F)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        itemCount: _filteredPosts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, idx) {
          final post = _filteredPosts[idx];
          final figure = post.figure;
          final isFollowed = widget.followedIds.contains(
            figure['figureID'].toString(),
          );
          final action = _actionMap.putIfAbsent(
            post.images.isNotEmpty ? post.images[0] : (post.video ?? ''),
            () => _ImageActionState(
              likeCount:
                  _likeCountMap[post.images.isNotEmpty
                      ? post.images[0]
                      : (post.video ?? '')] ??
                  0,
              commentCount:
                  widget
                      .commentsMap[post.images.isNotEmpty
                          ? post.images[0]
                          : (post.video ?? '')]
                      ?.length ??
                  0,
            ),
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: widget.avatarSize / 2,
                          backgroundImage: AssetImage(
                            figure['figureRecommendHeaderIcon'] ??
                                'assets/Image/applogo_2025_5_15.png',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              figure['figureName'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF2B1A2F),
                              ),
                            ),
                            Text(
                              _formatTimeSmart(post.time),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap:
                              () => widget.onToggleFollow(
                                figure['figureID'].toString(),
                              ),
                          child: Container(
                            width: 90,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient:
                                  isFollowed
                                      ? null
                                      : const LinearGradient(
                                        colors: [
                                          Color(0xFF69ACFF),
                                          Color(0xFFFF84FD),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                              color:
                                  isFollowed ? const Color(0xFFE0E0E0) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isFollowed ? 'Followed' : 'Follow',
                              style: TextStyle(
                                color:
                                    isFollowed
                                        ? Color(0xFF888888)
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2B1A2F),
                      ),
                    ),
                    if (post.images.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children:
                              post.images.map((img) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => FullScreenImageViewer(
                                                imagePath: img,
                                              ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        img,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    if (post.video != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => FullScreenVideoPlayer(
                                      videoPath: post.video!,
                                    ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 160,
                                  height: 96,
                                  color: Colors.black12,
                                  child:
                                      post.videoCoverBytes != null
                                          ? Image.memory(
                                            post.videoCoverBytes!,
                                            width: 160,
                                            height: 96,
                                            fit: BoxFit.cover,
                                          )
                                          : Center(
                                            child: SizedBox(
                                              width: 32,
                                              height: 32,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                ),
                              ),
                              Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    color: Color(0xFFB16CEA),
                                    size: 48,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    final String contentId =
                        post.images.isNotEmpty
                            ? post.images[0]
                            : (post.video ?? '');
                    final commentCount =
                        widget.commentsMap[contentId]?.length ?? 0;
                    final action = _actionMap.putIfAbsent(
                      contentId,
                      () => _ImageActionState(
                        likeCount: _likeCountMap[contentId] ?? 0,
                        commentCount: commentCount,
                      ),
                    );
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap:
                              () => _showImageReportSheet(
                                context,
                                post.figure,
                                contentId,
                              ),
                          child: Image.asset(
                            'assets/Image/btn_report_2025_5_16_n.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  action.liked = !action.liked;
                                  action.likeCount += action.liked ? 1 : -1;
                                });
                              },
                              child: Row(
                                children: [
                                  Image.asset(
                                    action.liked
                                        ? 'assets/Image/btn_like_2025_5_16_s.png'
                                        : 'assets/Image/btn_like_2025_5_16_n.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 17),
                                  Text(
                                    '${action.likeCount}',
                                    style: const TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 34),
                            GestureDetector(
                              onTap:
                                  () => _showImageCommentSheet(
                                    context,
                                    contentId,
                                    action,
                                  ),
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/Image/btn_message_2025_5_16_n.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                  const SizedBox(width: 17),
                                  Text(
                                    '$commentCount',
                                    style: const TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Container(height: 1, color: Color(0xFFF5F7F9)),
              ),
              const SizedBox(height: 23),
            ],
          );
        },
      ),
    );
  }
}

// ======= 新 ChatPage 实现 =======
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> _allFigures = [];
  List<Map<String, dynamic>> _hotFigures = [];
  List<_ContactItem> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. 加载所有角色
    final String jsonStr = await rootBundle.loadString(
      'assets/Image/chat/figures.json',
    );
    final List figuresList = json.decode(jsonStr);
    _allFigures = List<Map<String, dynamic>>.from(figuresList);
    // 2. 随机10个Hot角色
    _hotFigures = List<Map<String, dynamic>>.from(_allFigures)..shuffle();
    if (_hotFigures.length > 10) _hotFigures = _hotFigures.sublist(0, 10);
    // 3. 加载所有角色的聊天历史
    final prefs = await SharedPreferences.getInstance();
    List<_ContactItem> contacts = [];
    for (var figure in _allFigures) {
      final historyKey = 'chat_history_${figure['figureID']}';
      final historyStr = prefs.getString(historyKey);
      if (historyStr != null) {
        final List<dynamic> msgs = List<dynamic>.from(
          (historyStr.isNotEmpty) ? (jsonDecode(historyStr)) : [],
        );
        if (msgs.isNotEmpty) {
          final lastMsg = msgs.last;
          contacts.add(
            _ContactItem(
              figure: figure,
              lastMsg: lastMsg['content'] ?? '',
              lastTime:
                  DateTime.tryParse(lastMsg['time'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );
        }
      }
    }
    // 4. 按时间倒序排列
    contacts.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  void _openChat(Map<String, dynamic> figure) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoleChatPage(figure: figure)))
        .then((_) => _initData()); // 聊天后刷新
  }

  @override
  Widget build(BuildContext context) {
    final double topBgHeight = 180;
    final double hotCardRadius = 20;
    final double hotCardHeight = 126;
    final double avatarSize = 36;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Stack(
        children: [
          // 顶部背景
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/Image/top_bg_2025_5_16.png',
              width: MediaQuery.of(context).size.width,
              height: topBgHeight,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1A2F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Hot 区域
                Padding(
                  padding: const EdgeInsets.only(left: 0, right: 0),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Container(
                      color: Colors.white,
                      height: hotCardHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 15, right: 16),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/Image/chat_hot_2025_5_19.png',
                                  width: 22,
                                  height: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Hot',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF2B1A2F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _hotFigures.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 18),
                              itemBuilder: (context, idx) {
                                final f = _hotFigures[idx];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => FigureProfilePage(figure: f),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: avatarSize + 10,
                                    height: hotCardHeight - 22,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: avatarSize / 2,
                                              backgroundImage: AssetImage(
                                                f['figureRecommendHeaderIcon'] ??
                                                    'assets/Image/applogo_2025_5_15.png',
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 2,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Flexible(
                                          child: Text(
                                            f['figureNickname'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF888888),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 0),
                // Contact 区域
                Container(
                  height: 48,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 24),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/Image/chat_message_2025_5_19.png',
                          width: 22,
                          height: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Contact',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF2B1A2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 0),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child:
                        _loading
                            ? Center(child: CircularProgressIndicator())
                            : (_contacts.isEmpty
                                ? _buildNoContactView()
                                : ListView.separated(
                                  padding: const EdgeInsets.only(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                  ),
                                  itemCount: _contacts.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 2),
                                  itemBuilder: (context, idx) {
                                    final c = _contacts[idx];
                                    return ListTile(
                                      onTap: () => _openChat(c.figure),
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundImage: AssetImage(
                                              c.figure['figureRecommendHeaderIcon'] ??
                                                  'assets/Image/applogo_2025_5_15.png',
                                            ),
                                          ),
                                          Positioned(
                                            right: 2,
                                            top: 2,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(
                                        c.figure['figureNickname'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFF2B1A2F),
                                        ),
                                      ),
                                      subtitle: Text(
                                        c.lastMsg,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF888888),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        _formatTimeSmart(c.lastTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFB0B0B0),
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 8,
                                          ),
                                    );
                                  },
                                )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 没有历史聊天时，推荐随机角色
  Widget _buildNoContactView() {
    final List<Map<String, dynamic>> recommend =
        List<Map<String, dynamic>>.from(_allFigures)..shuffle();
    final showList =
        recommend.length > 10 ? recommend.sublist(0, 10) : recommend;
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
      itemCount: showList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final f = showList[idx];
        return ListTile(
          onTap: () => _openChat(f),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: AssetImage(
                  f['figureRecommendHeaderIcon'] ??
                      'assets/Image/applogo_2025_5_15.png',
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            f['figureNickname'] ?? '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF2B1A2F),
            ),
          ),
          subtitle: Text(
            f['figureRecommendIntroduce'] ?? '',
            style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.chat_bubble_outline,
            color: Color(0xFFB16CEA),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 8,
          ),
        );
      },
    );
  }

  String _formatTimeSmart(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      // 今天
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      // 非今天
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}

// 联系人数据结构
class _ContactItem {
  final Map<String, dynamic> figure;
  final String lastMsg;
  final DateTime lastTime;
  _ContactItem({
    required this.figure,
    required this.lastMsg,
    required this.lastTime,
  });
}
// ======= 新 ChatPage 实现结束 =======

class MainTabPage extends StatefulWidget {
  const MainTabPage({Key? key}) : super(key: key);

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    RecommendPage(),
    ExplorePage(),
    ChatPage(),
    ProfilePage(),
  ];

  static const List<String> _tabIconsNormal = [
    'assets/Image/tan_1_2025_5_15_n.png',
    'assets/Image/tan_2_2025_5_15_n.png',
    'assets/Image/tan_3_2025_5_15_n.png',
    'assets/Image/tan_4_2025_5_15_n.png',
  ];
  static const List<String> _tabIconsSelected = [
    'assets/Image/tan_1_2025_5_15_s.png',
    'assets/Image/tan_2_2025_5_15_s.png',
    'assets/Image/tan_3_2025_5_15_s.png',
    'assets/Image/tan_4_2025_5_15_s.png',
  ];
  static const List<String> _tabTitles = [
    'Recommend',
    'Explore',
    'Chat',
    'Profile',
  ];

  Widget _buildTabIcon(int index) {
    return Image.asset(
      _selectedIndex == index
          ? _tabIconsSelected[index]
          : _tabIconsNormal[index],
      width: 32,
      height: 32,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: List.generate(4, (index) {
          return BottomNavigationBarItem(
            icon: _buildTabIcon(index),
            label: _tabTitles[index],
          );
        }),
      ),
    );
  }
}

// 全屏图片预览组件
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const FullScreenImageViewer({Key? key, required this.imagePath})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
