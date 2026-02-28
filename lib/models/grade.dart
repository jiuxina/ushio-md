class Grade {
  final String id;
  final String courseId;
  final String courseName;
  final double score;
  final double credit;
  final double gradePoint; // 绩点
  final String semester;
  final String? rank; // 排名

  const Grade({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.score,
    required this.credit,
    required this.gradePoint,
    required this.semester,
    this.rank,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      gradePoint: (json['grade_point'] as num?)?.toDouble() ?? 0.0,
      semester: json['semester'] as String? ?? '',
      rank: json['rank'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'course_name': courseName,
      'score': score,
      'credit': credit,
      'grade_point': gradePoint,
      'semester': semester,
      'rank': rank,
    };
  }
}
