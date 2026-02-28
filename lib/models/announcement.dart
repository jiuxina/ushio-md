class Announcement {
  final String id;
  final String title;
  final String content;
  final String department; // 发布部门
  final String category; // 教务/办事/活动/安全
  final bool isImportant;
  final DateTime publishedAt;
  final DateTime? expiresAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.department,
    required this.category,
    this.isImportant = false,
    required this.publishedAt,
    this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      department: json['department'] as String? ?? '',
      category: json['category'] as String? ?? '',
      isImportant: json['is_important'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'department': department,
      'category': category,
      'is_important': isImportant,
      'published_at': publishedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
