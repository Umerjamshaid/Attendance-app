import 'package:geolocator/geolocator.dart';

class LocationService {
  
  /// 1. Get the user's secure, verified location
  Future<Position> getVerifiedLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled on the device.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on GPS.');
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Open app settings.');
    }

    // When we reach here, permissions are granted. Fetch the location.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    // --- ANTI-CHEAT CHECK ---
    // If isMocked is true, the user is using a Fake GPS app.
    if (position.isMocked) {
      throw Exception('Fake GPS detected. Please disable mock locations.');
    }

    // Optional Check: Accuracy threshold.
    if (position.accuracy > 100) {
      throw Exception('GPS signal is too weak. Go near a window.');
    }

    return position;
  }

  /// 2. Calculate the distance between User and Office in meters
  double calculateDistanceInMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
