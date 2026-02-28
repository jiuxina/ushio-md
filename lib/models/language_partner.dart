class LanguagePartner {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String nativeLanguage;
  final String learningLanguage;
  final String? college;
  final String? bio;
  final List<String> interests;
  final DateTime createdAt;

  const LanguagePartner({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.nativeLanguage,
    required this.learningLanguage,
    this.college,
    this.bio,
    this.interests = const [],
    required this.createdAt,
  });

  factory LanguagePartner.fromJson(Map<String, dynamic> json) {
    return LanguagePartner(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      nativeLanguage: json['native_language'] as String? ?? '',
      learningLanguage: json['learning_language'] as String? ?? '',
      college: json['college'] as String?,
      bio: json['bio'] as String?,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
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
      'native_language': nativeLanguage,
      'learning_language': learningLanguage,
      'college': college,
      'bio': bio,
      'interests': interests,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
