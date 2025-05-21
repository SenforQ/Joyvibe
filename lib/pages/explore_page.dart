import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/coins_check.dart';
import '../models/comment.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _commentController = TextEditingController();
  Map<String, List<Comment>> _comments = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TODO: Implement the build method
      body: Container(),
    );
  }

  Future<void> _addComment(String postId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // 检查是否有足够的coins
    final hasEnoughCoins = await CoinsCheck.checkCoinsForComment(context);
    if (!hasEnoughCoins) return;

    // 扣除coins
    await CoinsCheck.deductCoinsForComment();

    // 添加评论
    setState(() {
      _comments[postId] = [
        ...(_comments[postId] ?? []),
        Comment(
          commentID: DateTime.now().millisecondsSinceEpoch.toString(),
          figureID: int.parse(postId),
          userID: 'current_user',
          userName: 'You',
          content: text,
          time: DateTime.now().toString().substring(0, 16),
          userAvatar: 'assets/Image/default_avatar.png',
          likeCount: 0,
          isLiked: false,
        ),
      ];
    });
    _commentController.clear();
  }

  void _showCommentDialog(String postId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_commentController.text.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                await _addComment(postId);
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
