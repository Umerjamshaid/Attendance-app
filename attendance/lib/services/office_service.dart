import '../models/office_location_model.dart';

class OfficeService {
  // Hardcoded PIPFA Karachi office coordinates for now
  Future<OfficeLocationModel> getOfficeLocation() async {
    // In a real app, this would call an API
    return OfficeLocationModel(
      latitude: 24.8607,
      longitude: 67.0011,
      radiusInMeters: 100.0, // 100 meters
      name: 'PIPFA Karachi Office',
    );
  }

  Future<void> updateOfficeLocation(OfficeLocationModel newLocation) async {
    // In a real app, this would call an API to update the server
    // For now, we just simulate a delay
    await Future.delayed(const Duration(seconds: 1));
  }
}
