class VenueBooking {
  final String id;
  final String userId;
  final String venueId;
  final DateTime date;
  final String timeSlot; // e.g. "08:00-10:00"
  final String status; // pending/confirmed/cancelled/completed
  final DateTime createdAt;

  const VenueBooking({
    required this.id,
    required this.userId,
    required this.venueId,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.createdAt,
  });

  factory VenueBooking.fromJson(Map<String, dynamic> json) {
    return VenueBooking(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      timeSlot: json['time_slot'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'venue_id': venueId,
      'date': date.toIso8601String(),
      'time_slot': timeSlot,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
