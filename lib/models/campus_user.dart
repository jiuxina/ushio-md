class CampusUser {
  final String id;
  final String studentId; // 学号
  final String name;
  final String? avatar;
  final String college; // 学院
  final String major; // 专业
  final String grade; // 年级
  final String role; // 本科生/研究生/教师
  final String? phone;
  final String? email;
  final DateTime createdAt;

  const CampusUser({
    required this.id,
    required this.studentId,
    required this.name,
    this.avatar,
    required this.college,
    required this.major,
    required this.grade,
    required this.role,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory CampusUser.fromJson(Map<String, dynamic> json) {
    return CampusUser(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      college: json['college'] as String? ?? '',
      major: json['major'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'name': name,
      'avatar': avatar,
      'college': college,
      'major': major,
      'grade': grade,
      'role': role,
      'phone': phone,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CampusUser copyWith({
    String? id,
    String? studentId,
    String? name,
    String? avatar,
    String? college,
    String? major,
    String? grade,
    String? role,
    String? phone,
    String? email,
    DateTime? createdAt,
  }) {
    return CampusUser(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      college: college ?? this.college,
      major: major ?? this.major,
      grade: grade ?? this.grade,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
