import 'package:geolocator/geolocator.dart';

abstract interface class LocationGateway {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({required LocationSettings settings});
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  );
}

class GeolocatorLocationGateway implements LocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({required LocationSettings settings}) =>
      Geolocator.getCurrentPosition(locationSettings: settings);

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => Geolocator.distanceBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );
}

class LocationService {
  LocationService({LocationGateway? gateway})
    : _gateway = gateway ?? GeolocatorLocationGateway();

  final LocationGateway _gateway;

  /// 1. Get the user's secure, verified location
  Future<Position> getVerifiedLocation() async {
    // Test if location services are enabled on the device.
    final serviceEnabled = await _gateway.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on GPS.');
    }

    // Check permissions
    var permission = await _gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _gateway.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Open app settings.',
      );
    }

    // When we reach here, permissions are granted. Fetch the location.
    final position = await _gateway.getCurrentPosition(
      settings: const LocationSettings(accuracy: LocationAccuracy.high),
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
    return _gateway.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
