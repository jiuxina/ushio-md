class AttendanceRecord {
  final String id;
  final String courseId;
  final String courseName;
  final String studentId;
  final String studentName;
  final String status; // present/absent/late
  final DateTime checkedAt;

  const AttendanceRecord({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.checkedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      status: json['status'] as String? ?? 'present',
      checkedAt: json['checked_at'] != null
          ? DateTime.parse(json['checked_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'course_name': courseName,
      'student_id': studentId,
      'student_name': studentName,
      'status': status,
      'checked_at': checkedAt.toIso8601String(),
    };
  }
}
