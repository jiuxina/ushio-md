class CulturalEvent {
  final String id;
  final String title;
  final String? description;
  final String eventType; // festival / performance / workshop
  final String? ethnicGroup;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final String? imageUrl;
  final double sutuoCredits;
  final int participantCount;
  final DateTime createdAt;

  const CulturalEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventType,
    this.ethnicGroup,
    required this.startDate,
    this.endDate,
    this.location,
    this.imageUrl,
    this.sutuoCredits = 0,
    this.participantCount = 0,
    required this.createdAt,
  });

  factory CulturalEvent.fromJson(Map<String, dynamic> json) {
    return CulturalEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      eventType: json['event_type'] as String? ?? 'festival',
      ethnicGroup: json['ethnic_group'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      location: json['location'] as String?,
      imageUrl: json['image_url'] as String?,
      sutuoCredits: (json['sutuo_credits'] as num?)?.toDouble() ?? 0,
      participantCount: json['participant_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'event_type': eventType,
      'ethnic_group': ethnicGroup,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'location': location,
      'image_url': imageUrl,
      'sutuo_credits': sutuoCredits,
      'participant_count': participantCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
