import 'package:attendance/models/office_location_model.dart';

// ── 2D. LocationService
//    Responsible for: getting device GPS and checking if user is in office range

class LocationService {
  // Returns true if user is within office radius
  Future<bool> isUserAtOffice(OfficeLocation office) async {
    // final position = await Geolocator.getCurrentPosition(
    //   desiredAccuracy: LocationAccuracy.high,
    // );
    //
    // final distanceInMeters = Geolocator.distanceBetween(
    //   position.latitude,
    //   position.longitude,
    //   office.latitude,
    //   office.longitude,
    // );
    //
    // return distanceInMeters <= office.radiusInMeters;

    return true; // mock - always at office
  }
}
