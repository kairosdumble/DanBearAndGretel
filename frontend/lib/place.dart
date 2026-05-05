class Place {
  const Place({
    required this.id,
    required this.name,
    required this.roadAddress,
    required this.distanceMeters,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String roadAddress;
  final int distanceMeters;
  final double latitude;
  final double longitude;

  String? get distanceLabel {
    if (distanceMeters <= 0) {
      return null;
    }

    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)}km';
    }
    return '${distanceMeters}m';
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      roadAddress: json['roadAddress'] as String,
      distanceMeters: json['distanceMeters'] as int,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
    );
  }
}
