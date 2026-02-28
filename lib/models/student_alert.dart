class StudentAlert {
  final String id;
  final String studentId;
  final String studentName;
  final String college;
  final String alertLevel; // red/yellow/blue
  final String reason;
  final DateTime createdAt;

  const StudentAlert({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.college,
    required this.alertLevel,
    required this.reason,
    required this.createdAt,
  });

  factory StudentAlert.fromJson(Map<String, dynamic> json) {
    return StudentAlert(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      college: json['college'] as String? ?? '',
      alertLevel: json['alert_level'] as String? ?? 'blue',
      reason: json['reason'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'college': college,
      'alert_level': alertLevel,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
