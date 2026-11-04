import 'package:attendance/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('LocationService.getVerifiedLocation', () {
    test('rejects when location services are disabled', () async {
      final gateway = _FakeLocationGateway()..serviceEnabled = false;

      await expectLater(
        LocationService(gateway: gateway).getVerifiedLocation(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Location services are disabled'),
          ),
        ),
      );
      expect(gateway.permissionChecks, 0);
    });

    test('rejects when permission remains denied after request', () async {
      final gateway = _FakeLocationGateway()
        ..permission = LocationPermission.denied
        ..requestedPermission = LocationPermission.denied;

      await expectLater(
        LocationService(gateway: gateway).getVerifiedLocation(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Location permissions are denied'),
          ),
        ),
      );
      expect(gateway.permissionRequests, 1);
      expect(gateway.positionRequests, 0);
    });

    test('rejects permanently denied permission', () async {
      final gateway = _FakeLocationGateway()
        ..permission = LocationPermission.deniedForever;

      await expectLater(
        LocationService(gateway: gateway).getVerifiedLocation(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('permanently denied'),
          ),
        ),
      );
      expect(gateway.positionRequests, 0);
    });

    test('rejects mocked location', () async {
      final gateway = _FakeLocationGateway()
        ..position = _position(isMocked: true);

      await expectLater(
        LocationService(gateway: gateway).getVerifiedLocation(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Fake GPS detected'),
          ),
        ),
      );
    });

    test('rejects accuracy above the existing 100 meter threshold', () async {
      final gateway = _FakeLocationGateway()
        ..position = _position(accuracy: 101);

      await expectLater(
        LocationService(gateway: gateway).getVerifiedLocation(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('GPS signal is too weak'),
          ),
        ),
      );
    });

    test('returns a valid, accurate position', () async {
      final expected = _position(accuracy: 10);
      final gateway = _FakeLocationGateway()..position = expected;

      final actual = await LocationService(
        gateway: gateway,
      ).getVerifiedLocation();

      expect(actual, expected);
      expect(gateway.positionRequests, 1);
    });
  });
}

Position _position({double accuracy = 10, bool isMocked = false}) => Position(
  longitude: -122.08,
  latitude: 37.42,
  timestamp: DateTime(2026),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
  isMocked: isMocked,
);

class _FakeLocationGateway implements LocationGateway {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  Position position = _position();
  int permissionChecks = 0;
  int permissionRequests = 0;
  int positionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings settings,
  }) async {
    positionRequests++;
    return position;
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => 0;
}
