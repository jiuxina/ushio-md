class CommunityPost {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String content;
  final List<String> images;
  final String? topic; // 话题标签
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.content,
    this.images = const [],
    this.topic,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      content: json['content'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      topic: json['topic'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'content': content,
      'images': images,
      'topic': topic,
      'like_count': likeCount,
      'comment_count': commentCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
