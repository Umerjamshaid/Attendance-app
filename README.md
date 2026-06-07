# Attendance-app

A secure, anti-cheat location-based attendance tracking application built with Flutter and Dart.

## App Features

### 1. User Profile Screen
View your attendance overview and account settings with a clean, intuitive interface.

<img src="https://github.com/Umerjamshaid/Attendance-app/blob/main/screenshots/image1.png?raw=true" alt="Profile Screen" width="300"/>

### 2. Notifications
Stay updated with real-time notifications about attendance status, offers, and important announcements.

<img src="https://github.com/Umerjamshaid/Attendance-app/blob/main/screenshots/image2.png?raw=true" alt="Notifications Screen" width="300"/>

### 3. Admin Dashboard
Monitor live attendance overview and employee status with location-based tracking.

<img src="https://github.com/Umerjamshaid/Attendance-app/blob/main/screenshots/image3.png?raw=true" alt="Admin Dashboard" width="300"/>

### 4. Attendance History
Track your attendance history with verification status and timestamps.

<img src="https://github.com/Umerjamshaid/Attendance-app/blob/main/screenshots/image4.png?raw=true" alt="History Screen" width="300"/>

---

## Architecture Overview

Here is the exact architecture you need to implement secure, anti-cheat location tracking.

As a Senior Engineer, we separate concerns. Hardware logic (GPS) should never be mixed with Business logic (Attendance).

### The File Architecture You Need

You only need three specific files to make this work perfectly.

- **services/location_service.dart**: This file's only job is to talk to the phone's GPS hardware using the geolocator package. It knows nothing about attendance.

- **services/office_service.dart**: This fetches the coordinates (Latitude/Longitude) and the allowed Radius of your actual office from your backend or local storage.

- **providers/attendance_provider.dart**: This is the "Brain". When the user taps the button, this provider asks LocationService for the user's location, asks OfficeService for the target office location, and then calculates the distance.

---

## Building the LocationService (Anti-Cheat & GPS)

Here is the code for your `location_service.dart`. I have included the "Mock Location" (Fake GPS) check and the standard permission flow.

Your Task: Copy this into your empty location_service.dart file. Read the comments carefully; this is how you handle hardware securely.

```dart
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
    // highAccuracy takes longer and uses more battery, but is required for geofencing.
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // --- ANTI-CHEAT CHECK ---
    // If isMocked is true, the user is using a Fake GPS app (very common on Android).
    if (position.isMocked) {
      throw Exception('Fake GPS detected. Please disable mock locations.');
    }

    // Optional Check: Accuracy threshold. 
    // If the GPS signal is bouncing off buildings, it might say they are 500 meters away.
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
```

---

## Wiring It Together in the Provider

Now, you do not need a new "Location Provider." Your AttendanceProvider just needs to use this new service before it allows the check-in.

Your Task: Update the submitAttendance method inside your AttendanceProvider (or wherever your check-in logic lives) to look like this:

```dart
// Inside your AttendanceProvider or Check-In Logic
import '../services/location_service.dart';
import '../services/office_service.dart';

Future<bool> attemptCheckIn(String userId) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final locationService = LocationService();
    // Assuming officeService.getOffice() returns an object with lat, lng, and radius
    // final office = await _officeService.getOffice(); 
    
    // For this example, let's hardcode PIPFA's Karachi office coordinates
    final officeLat = 24.8607; 
    final officeLng = 67.0011;
    final allowedRadius = 100.0; // 100 meters

    // 1. Get the user's real, non-faked location
    final userPosition = await locationService.getVerifiedLocation();

    // 2. Calculate the distance
    final distance = locationService.calculateDistanceInMeters(
      userPosition.latitude,
      userPosition.longitude,
      officeLat,
      officeLng,
    );

    // 3. The Geofence Rule
    if (distance > allowedRadius) {
      // User is outside the circle!
      throw Exception('You are ${distance.toStringAsFixed(0)} meters away from the office. Move closer.');
    }

    // 4. If code reaches here, they are inside the office and not using a fake GPS.
    // Proceed with submitting attendance to your backend...
    // await _attendanceService.submitAttendance(...);
    
    _isLoading = false;
    notifyListeners();
    return true;

  } catch (e) {
    _isLoading = false;
    _error = e.toString().replaceAll('Exception: ', ''); // Clean up error for the UI
    notifyListeners();
    return false;
  }
}
```

---

## Summary of the Senior Approach

- **No bloated packages**: You aren't running background geofencing services that drain battery. You are doing a simple, instantaneous distance check when the user presses the button.

- **Anti-Cheat built-in**: `position.isMocked` stops Android developers from faking their coordinates.

- **Graceful degradation**: If GPS is off, or permissions are denied, the service throws a clean text exception which your UI displays properly.

---

## Implementation Guide: LocationService

Since your file needs to be set up correctly, here is the "Senior" way to structure it. Focus on the **Permission Flow**. You cannot just "get location"; you must handle the case where the user says "No."

```dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS hardware is actually ON
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on GPS.');
    }

    // 2. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissions are permanently denied. Open settings to fix.');
    }

    // 3. Get Position with high accuracy
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
```

---

## Implementation Guide: LocationProvider

This is where you bridge everything. Notice how it uses the `OfficeService` you already have.

```dart
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final OfficeService _officeService = OfficeService();

  double? _distanceFromOffice;
  bool _isChecking = false;

  bool get isWithinRange => (_distanceFromOffice ?? 9999) <= 100; // 100 meters

  Future<void> validateLocation() async {
    _isChecking = true;
    notifyListeners();

    try {
      // 1. Get current position
      final userPos = await _locationService.getCurrentPosition();

      // 2. Mock Check (Anti-Cheat)
      if (userPos.isMocked) {
        throw Exception("Please disable Fake GPS apps.");
      }

      // 3. Get Office location from your existing service
      final office = await _officeService.getOfficeLocation();
      if (office == null) throw Exception("Office location not configured.");

      // 4. Calculate Distance
      _distanceFromOffice = Geolocator.distanceBetween(
        userPos.latitude, userPos.longitude,
        office.latitude, office.longitude,
      );

    } catch (e) {
      // Handle error (e.g., show snackbar)
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}
```

---

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.
