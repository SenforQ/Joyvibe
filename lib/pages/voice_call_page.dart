import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class VoiceCallPage extends StatefulWidget {
  final Map<String, dynamic> figure;
  final Function(Map<String, dynamic>)? onMessageSent; // 支持消息回调
  const VoiceCallPage({Key? key, required this.figure, this.onMessageSent})
    : super(key: key);

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCallActive = true;
  Timer? _callTimer;
  int _remainingSeconds = 30;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isRinging = false;

  // 水波纹动画控制器
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // 随机回复消息列表
  final List<String> _replyMessages = [
    "Sorry, I was busy and missed your call. How are you doing now?",
    "I was in the middle of something and couldn't answer. What's up?",
    "Sorry, I was in a meeting. Are you free to talk now?",
    "I missed your call earlier. I'm available now, would you like me to call you back?",
    "Sorry I couldn't answer earlier. Are you free to chat now?",
    "I was occupied when you called. Is everything okay?",
    "Sorry about missing your call. What can I help you with?",
    "I was unavailable when you called. Would you like to talk now?",
    "Sorry I couldn't pick up. Is there something you needed?",
    "I was busy earlier. Are you free to talk now?",
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('VoiceCallPage: initState');
    _initAnimations();
    _startCall();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 水波纹动画
    _rippleController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  void _startCall() async {
    debugPrint('VoiceCallPage: Starting call');
    // 播放通话音效
    await _playCallSound();

    // 设置30秒后自动挂断的计时器
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _endCall();
      }
    });

    // 震动反馈
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
  }

  Future<void> _playCallSound() async {
    debugPrint('VoiceCallPage: Attempting to play ring sound');
    try {
      setState(() {
        _isRinging = true;
      });

      // 设置音量
      await _audioPlayer.setVolume(1.0);
      debugPrint('VoiceCallPage: Volume set to 1.0');

      // 设置循环播放
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      debugPrint('VoiceCallPage: Set to loop mode');

      // 播放铃声
      final source = AssetSource('sound/ring.mp3');
      debugPrint('VoiceCallPage: Playing sound from ${source.path}');
      await _audioPlayer.play(source);
      debugPrint('VoiceCallPage: Play command sent');

      // 监听播放状态
      _audioPlayer.onPlayerComplete.listen((_) {
        debugPrint('VoiceCallPage: Playback completed');
        if (mounted) {
          setState(() {
            _isRinging = false;
          });
        }
      });

      // 监听播放错误
      _audioPlayer.onLog.listen((String message) {
        debugPrint('VoiceCallPage: Audio player log: $message');
        if (message.contains('Error')) {
          debugPrint('VoiceCallPage: Error playing call sound: $message');
          if (mounted) {
            setState(() {
              _isRinging = false;
            });
          }
        }
      });

      // 监听播放状态变化
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        debugPrint('VoiceCallPage: Player state changed to: $state');
      });
    } catch (e) {
      debugPrint('VoiceCallPage: Error initializing call sound: $e');
      if (mounted) {
        setState(() {
          _isRinging = false;
        });
      }
    }
  }

  void _endCall() {
    debugPrint('VoiceCallPage: Ending call');
    _callTimer?.cancel();
    _audioPlayer.stop();
    _animationController.stop();
    _rippleController.stop();
    setState(() {
      _isCallActive = false;
      _isRinging = false;
    });

    // 震动反馈
    Vibration.vibrate(duration: 200);

    // 发送请求消息（用户消息）
    widget.onMessageSent?.call({
      'sender': 'me',
      'content': '[Request Voice Call]',
      'time': DateTime.now().toIso8601String(),
    });

    // 3-5秒后AI自动回复
    final delay = Duration(
      seconds: 3 + (DateTime.now().millisecondsSinceEpoch % 3),
    );
    Timer(delay, () {
      final randomMessage =
          _replyMessages[DateTime.now().millisecondsSinceEpoch %
              _replyMessages.length];
      widget.onMessageSent?.call({
        'sender': 'ai',
        'content': randomMessage,
        'time': DateTime.now().toIso8601String(),
      });
    });

    // 短暂延迟后返回上一页
    Timer(const Duration(milliseconds: 500), () {
      Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    debugPrint('VoiceCallPage: Disposing');
    _callTimer?.cancel();
    _audioPlayer.dispose();
    _animationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endCall();
        return false;
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 背景图片
            Image.asset(
              widget.figure['figurePhotoArray']?[0] ??
                  'assets/Image/applogo_2025_5_15.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

            // 渐变遮罩层
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // 通话界面内容
            SafeArea(
              child: Column(
                children: [
                  // 顶部状态栏
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: AssetImage(
                            widget.figure['figureRecommendHeaderIcon'] ??
                                'assets/Image/applogo_2025_5_15.png',
                          ),
                          radius: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.figure['figureNickname'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _isRinging
                                  ? 'Ringing...'
                                  : _isCallActive
                                  ? 'Voice call in progress'
                                  : 'Call ended',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 状态文字
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isCallActive ? _scaleAnimation.value : 1.0,
                        child: Text(
                          _isRinging
                              ? 'Waiting for answer...'
                              : _isCallActive
                              ? 'Call will end in $_remainingSeconds seconds'
                              : 'Call ended',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // 挂断按钮
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 水波纹效果
                      AnimatedBuilder(
                        animation: _rippleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_rippleAnimation.value * 0.3),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFB16CEA).withOpacity(0.3),
                                    const Color(0xFFF9CFE6).withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      // 按钮主体
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB16CEA), Color(0xFFF9CFE6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
