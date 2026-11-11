import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

enum EvidenceAddressStatus {
  found,
  notFound,
  unavailable,
  unsupported,
  invalid,
}

/// A provider-supplied display label, never a substitute for verified GPS.
class EvidenceAddress {
  const EvidenceAddress(this.status, [this.text]);
  final EvidenceAddressStatus status;
  final String? text;
}

typedef PlacemarkLookup =
    Future<List<Placemark>> Function(
      double latitude,
      double longitude,
      Locale locale,
    );
typedef _LocationKey = (double, double, String);

/// Session-only, bounded address cache. No coordinates or addresses go to disk.
class EvidenceLocationService {
  EvidenceLocationService({
    PlacemarkLookup? lookup,
    bool? supported,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 8),
    this.maxEntries = 64,
  }) : _lookup = lookup ?? _nativeLookup,
       _supported =
           supported ??
           (!kIsWeb &&
               const {
                 TargetPlatform.android,
                 TargetPlatform.iOS,
                 TargetPlatform.macOS,
               }.contains(defaultTargetPlatform)),
       _now = now ?? DateTime.now;

  final PlacemarkLookup _lookup;
  final bool _supported;
  final DateTime Function() _now;
  final Duration timeout;
  final int maxEntries;
  final _cache = <_LocationKey, (EvidenceAddress, DateTime)>{};
  final _pending = <_LocationKey, _PendingAddress>{};
  Future<void> _queue = Future.value();
  bool _disposed = false;

  static Future<List<Placemark>> _nativeLookup(
    double latitude,
    double longitude,
    Locale locale,
  ) =>
      Geocoding().placemarkFromCoordinates(latitude, longitude, locale: locale);

  /// Resolves exact saved coordinates, deduplicating matching locale requests.
  Future<EvidenceAddress> resolve(
    double? latitude,
    double? longitude, {
    required Locale locale,
    bool refresh = false,
  }) {
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return Future.value(const EvidenceAddress(EvidenceAddressStatus.invalid));
    }
    if (_disposed || !_supported) {
      return Future.value(
        const EvidenceAddress(EvidenceAddressStatus.unsupported),
      );
    }
    final key = (latitude, longitude, locale.toLanguageTag());
    final pending = _pending[key];
    if (pending != null) return pending.completer.future;
    final cached = _cache.remove(key);
    if (!refresh && cached != null && _now().isBefore(cached.$2)) {
      _cache[key] = cached;
      return Future.value(cached.$1);
    }

    final request = _PendingAddress();
    _pending[key] = request;
    void finish(EvidenceAddress address) {
      if (request.completer.isCompleted) return;
      _pending.remove(key);
      if (!_disposed && maxEntries > 0) {
        final ttl = address.status == EvidenceAddressStatus.found
            ? const Duration(hours: 24)
            : const Duration(seconds: 30);
        _cache[key] = (address, _now().add(ttl));
        while (_cache.length > maxEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      request.complete(address);
    }

    request.timer = Timer(timeout, () {
      finish(const EvidenceAddress(EvidenceAddressStatus.unavailable));
    });
    // A UI timeout cannot cancel native geocoding. Keep its slot until it ends.
    _queue = _queue.then((_) async {
      if (_disposed || request.completer.isCompleted) return;
      try {
        final placemarks = await _lookup(latitude, longitude, locale);
        for (final placemark in placemarks) {
          final text = formatEvidenceAddress(placemark);
          if (text.isNotEmpty) {
            finish(EvidenceAddress(EvidenceAddressStatus.found, text));
            return;
          }
        }
        finish(const EvidenceAddress(EvidenceAddressStatus.notFound));
      } catch (_) {
        finish(const EvidenceAddress(EvidenceAddressStatus.unavailable));
      }
    });
    return request.completer.future;
  }

  /// Drops sensitive labels and completes waiters when the account scope ends.
  void dispose() {
    _disposed = true;
    _cache.clear();
    for (final request in _pending.values) {
      request.complete(
        const EvidenceAddress(EvidenceAddressStatus.unavailable),
      );
    }
    _pending.clear();
  }
}

class _PendingAddress {
  final completer = Completer<EvidenceAddress>();
  Timer? timer;

  void complete(EvidenceAddress address) {
    if (completer.isCompleted) return;
    timer?.cancel();
    completer.complete(address);
  }
}

/// Uses only supplied components from one placemark, without guessing details.
String formatEvidenceAddress(Placemark placemark) {
  String clean(String? value) =>
      (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  final street = clean(placemark.street);
  final name = clean(placemark.name);
  final streetParts = [
    clean(placemark.subThoroughfare),
    clean(placemark.thoroughfare),
  ].where((part) => part.isNotEmpty).join(' ');
  final parts = [
    if (name.isNotEmpty && !RegExp(r'^[\d\s.,+\-]+$').hasMatch(name)) name,
    street.isNotEmpty ? street : streetParts,
    placemark.subLocality,
    placemark.locality,
    placemark.subAdministrativeArea,
    placemark.administrativeArea,
    placemark.postalCode,
    placemark.country,
  ];
  final seen = <String>{};
  return [
    for (final part in parts)
      for (final component in clean(part).split(','))
        if (component.trim().isNotEmpty &&
            seen.add(component.trim().toLowerCase()))
          component.trim(),
  ].join(', ');
}
