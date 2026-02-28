class Venue {
  final String id;
  final String name;
  final String type; // 羽毛球/篮球/自习室/会议室
  final String location;
  final int capacity;
  final bool isAvailable;
  final String? imageUrl;
  final String? description;

  const Venue({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.capacity,
    this.isAvailable = true,
    this.imageUrl,
    this.description,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      location: json['location'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'location': location,
      'capacity': capacity,
      'is_available': isAvailable,
      'image_url': imageUrl,
      'description': description,
    };
  }
}
