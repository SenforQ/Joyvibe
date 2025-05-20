import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/cupertino.dart';
import 'report_page.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'voice_call_page.dart';

class RoleChatPage extends StatefulWidget {
  final Map<String, dynamic> figure;
  const RoleChatPage({Key? key, required this.figure}) : super(key: key);

  @override
  State<RoleChatPage> createState() => _RoleChatPageState();
}

class _RoleChatPageState extends State<RoleChatPage> {
  List<Map<String, dynamic>> _messages = [];
  TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _myAvatar;
  String? _myName;
  String? _appDocPath;
  late String _historyKey;
  VideoPlayerController? _videoController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _historyKey = 'chat_history_${widget.figure['figureID']}';
    _initProfileAndHistory();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initProfileAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar =
        prefs.getString('profile_avatar') ??
        'assets/Image/applogo_2025_5_15.png';
    final name = prefs.getString('profile_nickname') ?? 'Me';
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _myAvatar = avatar;
      _myName = name;
      _appDocPath = dir.path;
    });
    // 加载历史
    final historyStr = prefs.getString(_historyKey);
    if (historyStr != null) {
      setState(() {
        _messages = _decodeMessagesFromLoad(json.decode(historyStr));
      });
      _scrollToBottom();
    } else {
      // 首次进入，自动插入AI欢迎语
      setState(() {
        _messages = [
          {
            'sender': 'ai',
            'content': widget.figure['figureChatOpen'] ?? 'Hello!',
            'time': DateTime.now().toIso8601String(),
          },
        ];
      });
      await _saveHistory();
      _scrollToBottom();
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      json.encode(_encodeMessagesForSave(_messages)),
    );
  }

  List<Map<String, dynamic>> _encodeMessagesForSave(
    List<Map<String, dynamic>> msgs,
  ) {
    return msgs.map((msg) {
      final m = Map<String, dynamic>.from(msg);
      if (m['type'] == 'video' && m['cover'] is Uint8List) {
        m['cover'] = base64Encode(m['cover']);
      }
      return m;
    }).toList();
  }

  List<Map<String, dynamic>> _decodeMessagesFromLoad(List msgs) {
    return msgs.map<Map<String, dynamic>>((msg) {
      final m = Map<String, dynamic>.from(msg);
      if (m['type'] == 'video' && m['cover'] is String) {
        final coverStr = m['cover'] as String;
        // 只对非assets/开头的字符串做base64Decode
        if (!coverStr.startsWith('assets/')) {
          m['cover'] = base64Decode(coverStr);
        }
        // 否则直接保留原字符串
      }
      return m;
    }).toList();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'sender': 'me',
        'content': text.trim(),
        'time': DateTime.now().toIso8601String(),
      });
      _loading = true;
    });
    _controller.clear();
    await _saveHistory();
    _scrollToBottom();
    // 请求AI
    final aiReply = await _fetchAiReply(text);
    setState(() {
      _messages.add({
        'sender': 'ai',
        'content': aiReply,
        'time': DateTime.now().toIso8601String(),
      });
      _loading = false;
    });
    await _saveHistory();
    _scrollToBottom();
  }

  Future<String> _fetchAiReply(String userInput) async {
    // 拼接历史上下文
    List<Map<String, String>> history = [];
    for (var msg in _messages) {
      history.add({
        'role': msg['sender'] == 'me' ? 'user' : 'assistant',
        'content': msg['content'],
      });
    }
    history.add({'role': 'user', 'content': userInput});
    final url = Uri.parse(
      'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Authorization':
          'Bearer 84c9cf80573340c38fb696ee66c179a9.UQsxCmRLuh9EuqmK',
    };
    final body = json.encode({
      'model': 'glm-4-flash',
      'messages': history,
      'max_tokens': 1024,
      'temperature': 0.7,
    });
    try {
      final resp = await http.post(url, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['choices'][0]['message']['content'] ??
            'Sorry, I have no answer.';
      } else {
        return 'AI service error: ${resp.statusCode}';
      }
    } catch (e) {
      return 'Network error, please try again.';
    }
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isMe = msg['sender'] == 'me';
    final isBlocked = _isBlocked(widget.figure['figureID']);
    final avatar =
        isMe
            ? (_myAvatar != null && !_myAvatar!.startsWith('assets/')
                ? FileImage(File('${_appDocPath ?? ''}/${_myAvatar}'))
                : AssetImage(_myAvatar ?? 'assets/Image/applogo_2025_5_15.png'))
            : AssetImage(widget.figure['figureRecommendHeaderIcon'] ?? '');
    final name = isMe ? _myName ?? 'Me' : widget.figure['figureNickname'] ?? '';
    // 图片消息
    if (msg['type'] == 'image') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 22,
                backgroundImage: avatar as ImageProvider,
              ),
            if (!isMe) const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: InteractiveViewer(
                            child: Image.asset(
                              msg['content'],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  msg['content'],
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe)
              CircleAvatar(
                radius: 22,
                backgroundImage: avatar as ImageProvider,
              ),
          ],
        ),
      );
    }
    // 视频消息
    if (msg['type'] == 'video') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 22,
                backgroundImage: avatar as ImageProvider,
              ),
            if (!isMe) const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => FullScreenVideoPlayer(videoPath: msg['content']),
                  ),
                );
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black12,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          msg['cover'] != null && msg['cover'] is Uint8List
                              ? Image.memory(
                                msg['cover'],
                                width: 160,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                              : Container(color: Colors.black12),
                    ),
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe)
              CircleAvatar(
                radius: 22,
                backgroundImage: avatar as ImageProvider,
              ),
          ],
        ),
      );
    }
    // 文本消息
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(radius: 22, backgroundImage: avatar as ImageProvider),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? const Color(0xFFF9CFE6)
                        : isBlocked
                        ? const Color(0xFFE0E0E0)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  if (!isMe && !isBlocked)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Text(
                msg['content'],
                style: TextStyle(
                  color:
                      isMe
                          ? Colors.black87
                          : isBlocked
                          ? const Color(0xFF888888)
                          : Colors.black87,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(radius: 22, backgroundImage: avatar as ImageProvider),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final figure = widget.figure;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(
                figure['figureRecommendHeaderIcon'] ?? '',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              figure['figureNickname'] ?? '',
              style: const TextStyle(
                color: Color(0xFF4B2B3A),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black54),
            tooltip: 'Delete chat',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete Chat'),
                      content: const Text(
                        'Are you sure you want to delete all chat history with this role?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_historyKey);
                setState(() {
                  _messages = [
                    {
                      'sender': 'ai',
                      'content': widget.figure['figureChatOpen'] ?? 'Hello!',
                      'time': DateTime.now().toIso8601String(),
                    },
                  ];
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder:
                    (context) => CupertinoActionSheet(
                      title: const Text('More'),
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportPage(rec: widget.figure),
                              ),
                            );
                          },
                          child: const Text('Report'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _toggleBlock(figure['figureID']);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setStringList(
                              'blocked_role_ids',
                              _blockedIds.toList(),
                            );
                            setState(() {});
                          },
                          isDestructiveAction: _isBlocked(figure['figureID']),
                          child: Text(
                            _isBlocked(figure['figureID'])
                                ? 'Unblock'
                                : 'Block',
                          ),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 顶部渐变图片，y=0
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/Image/top_bg_2025_5_16.png',
              width: screenWidth,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          // 内容区用SafeArea包裹
          SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: false,
                    padding: const EdgeInsets.only(top: 0, bottom: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      return _buildMessage(_messages[idx]);
                    },
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildMediaButton(
                        icon: Icons.image,
                        label: 'Request Image',
                        onTap:
                            _isBlocked(widget.figure['figureID'])
                                ? null
                                : () => _requestMedia('image'),
                      ),
                      const SizedBox(width: 8),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        label: 'Request Video',
                        onTap:
                            _isBlocked(widget.figure['figureID'])
                                ? null
                                : () => _requestMedia('video'),
                      ),
                      const SizedBox(width: 8),
                      _buildMediaButton(
                        icon: Icons.call,
                        label: 'Voice Call',
                        onTap:
                            _isBlocked(widget.figure['figureID'])
                                ? null
                                : _requestCall,
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E6EB),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: TextField(
                            controller: _controller,
                            enabled: !_isBlocked(widget.figure['figureID']),
                            decoration: InputDecoration(
                              hintText:
                                  _isBlocked(widget.figure['figureID'])
                                      ? 'Blocked, unable to send message'
                                      : 'Say something...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 16),
                            onSubmitted: (v) {
                              if (!_loading &&
                                  !_isBlocked(widget.figure['figureID']))
                                _sendMessage(v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap:
                            _loading || _isBlocked(widget.figure['figureID'])
                                ? null
                                : () => _sendMessage(_controller.text),
                        child: Container(
                          width: 88,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors:
                                  _isBlocked(widget.figure['figureID'])
                                      ? [
                                        const Color(0xFFCCCCCC),
                                        const Color(0xFFCCCCCC),
                                      ]
                                      : [
                                        const Color(0xFFB16CEA),
                                        const Color(0xFFF9CFE6),
                                      ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child:
                              _loading
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'Send',
                                    style: TextStyle(
                                      color:
                                          _isBlocked(widget.figure['figureID'])
                                              ? Colors.white70
                                              : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 拉黑/屏蔽功能
  Set<String> _blockedIds = {};
  bool _isBlocked(dynamic figureID) {
    return _blockedIds.contains(figureID.toString());
  }

  Future<void> _toggleBlock(dynamic figureID) async {
    final id = figureID.toString();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocked_role_ids') ?? [];
    setState(() {
      if (_blockedIds.contains(id)) {
        _blockedIds.remove(id);
        list.remove(id);
      } else {
        _blockedIds.add(id);
        list.add(id);
      }
    });
    await prefs.setStringList('blocked_role_ids', list);
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[300] : const Color(0xFFF9CFE6),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onTap == null ? Colors.grey : Color(0xFFDB64A5),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 7.5,
                color: onTap == null ? Colors.grey : Color(0xFF4B2B3A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestMedia(String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Request ${type == 'image' ? 'Image' : 'Video'}'),
            content: const Text(
              'The other party needs to agree before sending. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Request'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    // 1. 先插入"用户"请求消息
    setState(() {
      _messages.add({
        'sender': 'me',
        'content': type == 'image' ? '[Request Image]' : '[Request Video]',
        'time': DateTime.now().toIso8601String(),
      });
    });
    await _saveHistory();
    _scrollToBottom();
    // 2. 角色同意后立即插入图片/视频
    if (type == 'image') {
      final List<dynamic> photos = widget.figure['figurePhotoArray'] ?? [];
      if (photos.isNotEmpty) {
        final img = (photos..shuffle()).first;
        setState(() {
          _messages.add({
            'sender': 'ai',
            'type': 'image',
            'content': img,
            'time': DateTime.now().toIso8601String(),
          });
        });
        await _saveHistory();
        _scrollToBottom();
      }
    } else if (type == 'video') {
      final List<dynamic> videos = widget.figure['figureVideoArray'] ?? [];
      if (videos.isNotEmpty) {
        final vid = (videos..shuffle()).first;
        Uint8List? coverBytes;
        try {
          final tempPath = await _copyAssetToTemp(vid);
          coverBytes = await VideoThumbnail.thumbnailData(
            video: tempPath,
            imageFormat: ImageFormat.PNG,
            maxWidth: 320,
            quality: 75,
          );
        } catch (_) {}
        setState(() {
          _messages.add({
            'sender': 'ai',
            'type': 'video',
            'content': vid,
            'cover': coverBytes,
            'time': DateTime.now().toIso8601String(),
          });
        });
        await _saveHistory();
        _scrollToBottom();
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

  void _requestCall() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Voice Call'),
            content: const Text(
              'The other party needs to agree before starting a call. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Request'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      // 1. 先插入"用户"请求消息
      setState(() {
        _messages.add({
          'sender': 'me',
          'content': '[Request Voice Call]',
          'time': DateTime.now().toIso8601String(),
        });
      });
      await _saveHistory();
      _scrollToBottom();
      // 2. 不自动请求AI回复
      // 3. 跳转到通话页面
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VoiceCallPage(figure: widget.figure)),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  const FullScreenVideoPlayer({Key? key, required this.videoPath})
    : super(key: key);
  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child:
                _controller.value.isInitialized
                    ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                    : const CircularProgressIndicator(),
          ),
          // 顶部关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),
          ),
          // 底部控制栏
          if (_controller.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Column(
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(playedColor: Color(0xFFDB64A5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                            });
                          },
                        ),
                        Text(
                          _formatDuration(_controller.value.position) +
                              ' / ' +
                              _formatDuration(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        // 可扩展倍速、分享等按钮
                      ],
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
