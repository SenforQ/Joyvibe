class Comment {
  final String commentID;
  final int figureID;
  final String userID;
  final String userName;
  final String userAvatar;
  final String content;
  final String time;
  int likeCount;
  bool isLiked;

  Comment({
    required this.commentID,
    required this.figureID,
    required this.userID,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.time,
    required this.likeCount,
    required this.isLiked,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    commentID: json['commentID'],
    figureID: json['figureID'],
    userID: json['userID'],
    userName: json['userName'],
    userAvatar: json['userAvatar'],
    content: json['content'],
    time: json['time'],
    likeCount: json['likeCount'],
    isLiked: json['isLiked'],
  );
}
