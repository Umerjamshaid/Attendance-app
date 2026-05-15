import '../models/office_location_model.dart';

import 'package:geolocator/geolocator.dart';

class OfficeService {
  // Hardcoded PIPFA Karachi office coordinates for now
  Future<OfficeLocationModel> getOfficeLocation() async {
    // Temporarily return the admin-saved coordinates
    // (Later you'll fetch from Firebase)
    return OfficeLocationModel(
      latitude: 37.4219983, // User enters this via SetOfficeLocationSheet
      longitude: -122.084, // User enters this via SetOfficeLocationSheet
      radiusInMeters: 100,
      name: 'Office',
    );
  }

  Future<void> updateOfficeLocation(OfficeLocationModel newLocation) async {
    // In a real app, this would call an API to update the server
    // For now, we just simulate a delay
    await Future.delayed(const Duration(seconds: 1));
  }

  // Inside OfficeService class
  Future<Position> determineCurrentPosition() async {
    // STEP 1: Create a variable to check if location services are enabled
    // Logic: If Geolocator.isLocationServiceEnabled() is false, throw an error.
    // USE try-catch if you like it.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS is disabled. Please turn it on.');
    }

    // STEP 2: Check permissions
    // Logic: Use Geolocator.checkPermission().
    // If it's 'denied', call Geolocator.requestPermission().
    // If it's 'deniedForever', tell the user they must go to settings.
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable them in app settings.',
      );
    }

    // STEP 3: Get the actual position
    // Logic: Return await Geolocator.getCurrentPosition()
    // Tip: Use LocationAccuracy.high for office setups.

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return position;
    } catch (e) {
      throw Exception('Failed to get location: ${e.toString()}');
    }
  }

  // Calculate distance between two points
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // Check if user is inside office radius
  Future<bool> isUserInOffice(Position userPosition) async {
    final office = await getOfficeLocation();
    final distance = _calculateDistance(
      office.latitude,
      office.longitude,
      userPosition.latitude,
      userPosition.longitude,
    );
    return distance <= office.radiusInMeters;
  }
}
