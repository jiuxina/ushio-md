class Course {
  final String id;
  final String name;
  final String teacher;
  final String location; // 教室
  final int dayOfWeek; // 1-7
  final int startPeriod; // 开始节次
  final int endPeriod; // 结束节次
  final int startWeek;
  final int endWeek;
  final String? semester; // 学期
  final double? credit; // 学分

  const Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    required this.startWeek,
    required this.endWeek,
    this.semester,
    this.credit,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      location: json['location'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as int? ?? 1,
      startPeriod: json['start_period'] as int? ?? 1,
      endPeriod: json['end_period'] as int? ?? 1,
      startWeek: json['start_week'] as int? ?? 1,
      endWeek: json['end_week'] as int? ?? 1,
      semester: json['semester'] as String?,
      credit: (json['credit'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'location': location,
      'day_of_week': dayOfWeek,
      'start_period': startPeriod,
      'end_period': endPeriod,
      'start_week': startWeek,
      'end_week': endWeek,
      'semester': semester,
      'credit': credit,
    };
  }
}
