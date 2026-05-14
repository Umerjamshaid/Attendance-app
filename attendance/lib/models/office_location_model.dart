// ─────────────────────────────────────────────────────────────
//  SECTION 1 — MODELS
//  Plain Dart classes. No logic. Just data shapes.
// ─────────────────────────────────────────────────────────────

class OfficeLocationModel {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusInMeters;

  OfficeLocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusInMeters,
  });

  factory OfficeLocationModel.fromMap(Map<String, dynamic> map) {
    return OfficeLocationModel(
      name: map['name'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      radiusInMeters: (map['radiusInMeters'] ?? 100).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusInMeters': radiusInMeters,
  };
}
