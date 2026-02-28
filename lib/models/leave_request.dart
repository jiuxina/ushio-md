class LeaveRequest {
  final String id;
  final String userId;
  final String type; // 事假/病假/公假/其他
  final DateTime startTime;
  final DateTime endTime;
  final String reason;
  final String? destination; // 离校去向
  final List<String> attachments; // 证明材料URLs
  final String status; // pending/approved/rejected/cancelled
  final String? reviewerComment;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.reason,
    this.destination,
    this.attachments = const [],
    required this.status,
    this.reviewerComment,
    required this.createdAt,
    this.reviewedAt,
  });

  /// 请假时长
  Duration get duration {
    final diff = endTime.difference(startTime);
    return diff.isNegative ? Duration.zero : diff;
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : DateTime.now(),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : DateTime.now(),
      reason: json['reason'] as String? ?? '',
      destination: json['destination'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'pending',
      reviewerComment: json['reviewer_comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'reason': reason,
      'destination': destination,
      'attachments': attachments,
      'status': status,
      'reviewer_comment': reviewerComment,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }
}
