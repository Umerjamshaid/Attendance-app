import 'dart:async';

import 'package:attendance/services/evidence_location_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

const _locale = Locale('en');
const _place = Placemark(
  name: 'Block B',
  street: 'Street 34',
  subLocality: 'Block B',
  locality: 'Lahore',
  subAdministrativeArea: 'Lahore',
  administrativeArea: 'Punjab',
  country: 'Pakistan',
);

void main() {
  test('formats only returned components and removes duplicate segments', () {
    expect(
      formatEvidenceAddress(_place),
      'Block B, Street 34, Lahore, Punjab, Pakistan',
    );
    expect(
      formatEvidenceAddress(
        const Placemark(
          street: 'Street 34, Block B',
          subLocality: 'block b',
          locality: 'Lahore',
        ),
      ),
      'Street 34, Block B, Lahore',
    );
  });

  test('partial and non-Latin addresses do not acquire invented streets', () {
    expect(
      formatEvidenceAddress(
        const Placemark(
          locality: 'Lahore',
          administrativeArea: 'Punjab',
          country: 'Pakistan',
        ),
      ),
      'Lahore, Punjab, Pakistan',
    );
    expect(
      formatEvidenceAddress(
        const Placemark(locality: '  لاہور  ', country: 'پاکستان'),
      ),
      'لاہور, پاکستان',
    );
    expect(
      formatEvidenceAddress(const Placemark(name: '31.5204, 74.3587')),
      '',
    );
    expect(
      formatEvidenceAddress(
        const Placemark(
          name: '34',
          thoroughfare: 'Example Road',
          subThoroughfare: '34',
        ),
      ),
      '34 Example Road',
    );
  });

  test(
    'uses one candidate, never merges different candidate addresses',
    () async {
      final service = EvidenceLocationService(
        supported: true,
        lookup: (_, _, _) async => [
          const Placemark(),
          const Placemark(locality: 'Lahore'),
          const Placemark(street: 'A different road', locality: 'Karachi'),
        ],
      );
      addTearDown(service.dispose);
      expect((await service.resolve(31, 74, locale: _locale)).text, 'Lahore');
    },
  );

  test(
    'deduplicates in-flight requests and caches exact coordinates per locale',
    () async {
      var calls = 0;
      final pending = Completer<List<Placemark>>();
      final service = EvidenceLocationService(
        supported: true,
        lookup: (_, _, _) {
          calls++;
          return pending.future;
        },
      );
      addTearDown(service.dispose);
      final first = service.resolve(31, 74, locale: _locale);
      final second = service.resolve(31, 74, locale: _locale);
      expect(identical(first, second), true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      pending.complete([_place]);
      expect((await first).status, EvidenceAddressStatus.found);
      await service.resolve(31, 74, locale: _locale);
      expect(calls, 1);
      await service.resolve(31, 74, locale: const Locale('ur'));
      await service.resolve(31.000001, 74, locale: _locale);
      expect(calls, 3);
    },
  );

  test(
    'successful labels expire after 24 hours and cache has an LRU bound',
    () async {
      var now = DateTime(2026, 11, 11);
      var calls = 0;
      final service = EvidenceLocationService(
        supported: true,
        maxEntries: 2,
        now: () => now,
        lookup: (_, _, _) async {
          calls++;
          return [_place];
        },
      );
      addTearDown(service.dispose);
      await service.resolve(1, 1, locale: _locale);
      await service.resolve(2, 2, locale: _locale);
      await service.resolve(1, 1, locale: _locale);
      await service.resolve(3, 3, locale: _locale);
      await service.resolve(2, 2, locale: _locale);
      expect(calls, 4);
      now = now.add(const Duration(hours: 24));
      await service.resolve(2, 2, locale: _locale);
      expect(calls, 5);
    },
  );

  test(
    'empty results and errors use a short cooldown; explicit retry can recover',
    () async {
      var calls = 0;
      var now = DateTime(2026, 11, 11);
      final service = EvidenceLocationService(
        supported: true,
        now: () => now,
        lookup: (_, _, _) async {
          calls++;
          if (calls == 1) throw Exception('Platform geocoder unavailable');
          return calls == 2 ? [] : [_place];
        },
      );
      addTearDown(service.dispose);
      expect(
        (await service.resolve(31, 74, locale: _locale)).status,
        EvidenceAddressStatus.unavailable,
      );
      await service.resolve(31, 74, locale: _locale);
      expect(calls, 1);
      now = now.add(const Duration(seconds: 31));
      expect(
        (await service.resolve(31, 74, locale: _locale)).status,
        EvidenceAddressStatus.notFound,
      );
      expect(
        (await service.resolve(31, 74, locale: _locale, refresh: true)).text,
        'Block B, Street 34, Lahore, Punjab, Pakistan',
      );
      expect(calls, 3);
    },
  );

  test(
    'invalid coordinates and unsupported platforms never call a provider',
    () async {
      var calls = 0;
      Future<List<Placemark>> lookup(double a, double b, Locale c) async {
        calls++;
        return [_place];
      }

      final service = EvidenceLocationService(supported: true, lookup: lookup);
      addTearDown(service.dispose);
      for (final pair in <(double?, double?)>[
        (null, 74),
        (31, null),
        (double.nan, 74),
        (31, double.infinity),
        (-91, 74),
        (91, 74),
        (31, -181),
        (31, 181),
      ]) {
        expect(
          (await service.resolve(pair.$1, pair.$2, locale: _locale)).status,
          EvidenceAddressStatus.invalid,
        );
      }
      final unsupported = EvidenceLocationService(
        supported: false,
        lookup: lookup,
      );
      addTearDown(unsupported.dispose);
      expect(
        (await unsupported.resolve(31, 74, locale: _locale)).status,
        EvidenceAddressStatus.unsupported,
      );
      expect(calls, 0);
    },
  );

  testWidgets(
    'timeout unblocks UI without overlapping native work or caching late data',
    (tester) async {
      var calls = 0;
      final native = Completer<List<Placemark>>();
      final service = EvidenceLocationService(
        supported: true,
        timeout: const Duration(seconds: 1),
        lookup: (_, _, _) {
          calls++;
          return native.future;
        },
      );
      addTearDown(service.dispose);
      final first = service.resolve(31, 74, locale: _locale);
      await tester.pump();
      final second = service.resolve(32, 75, locale: _locale);
      await tester.pump(const Duration(seconds: 2));
      expect((await first).status, EvidenceAddressStatus.unavailable);
      expect((await second).status, EvidenceAddressStatus.unavailable);
      expect(calls, 1);
      native.complete([_place]);
      await tester.pump();
      expect(calls, 1);
      expect(
        (await service.resolve(31, 74, locale: _locale)).status,
        EvidenceAddressStatus.unavailable,
      );
    },
  );

  test(
    'account disposal completes pending work and drops cached data',
    () async {
      final pending = Completer<List<Placemark>>();
      final service = EvidenceLocationService(
        supported: true,
        lookup: (_, _, _) => pending.future,
      );
      final future = service.resolve(31, 74, locale: _locale);
      await Future<void>.delayed(Duration.zero);
      service.dispose();
      expect((await future).status, EvidenceAddressStatus.unavailable);
      pending.complete([_place]);
      await Future<void>.delayed(Duration.zero);
      expect(
        (await service.resolve(31, 74, locale: _locale)).status,
        EvidenceAddressStatus.unsupported,
      );
    },
  );
}
