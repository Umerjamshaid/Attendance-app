import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/attendance_evidence_screen.dart';
import 'package:attendance/services/evidence_location_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

final _record = AttendanceRecord(
  id: 'record-1',
  userId: 'EMP001',
  isPresent: true,
  timestamp: DateTime(2026, 11, 11, 9, 5),
  device: 'Sample Android device',
);
const _address = 'Block B, Street 34, Lahore, Punjab, Pakistan';
const _place = Placemark(
  name: 'Block B',
  street: 'Street 34',
  locality: 'Lahore',
  administrativeArea: 'Punjab',
  country: 'Pakistan',
);

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'location loading never blocks the photo, stored coordinates or other evidence',
    (tester) async {
      final pending = Completer<List<Placemark>>();
      var calls = 0;
      final service = EvidenceLocationService(
        supported: true,
        lookup: (lat, lng, locale) {
          calls++;
          expect((lat, lng), (31.5204, 74.3587));
          return pending.future;
        },
      );
      final backend = _Backend();
      await _mount(tester, service, backend);
      await tester.pump();
      expect(find.text('Resolving location...'), findsOneWidget);
      _expectOriginalEvidence(tester);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<NetworkImage>().having(
          (image) => image.url,
          'url',
          'https://example.invalid/photo.jpg',
        ),
      );
      pending.complete([_place]);
      await tester.pumpAndSettle();
      expect(find.text(_address), findsOneWidget);
      expect(find.text('Resolving location...'), findsNothing);
      expect(calls, 1);
      expect(backend.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed address lookup can retry without reloading evidence', (
    tester,
  ) async {
    var calls = 0;
    final service = EvidenceLocationService(
      supported: true,
      lookup: (_, _, _) async {
        if (++calls == 1) throw Exception('Native geocoder offline');
        return [_place];
      },
    );
    final backend = _Backend();
    await _mount(tester, service, backend);
    await tester.pumpAndSettle();
    expect(
      find.text('Address unavailable. Coordinates are shown below.'),
      findsOneWidget,
    );
    _expectOriginalEvidence(tester);
    await tester.ensureVisible(find.text('Retry location'));
    await tester.tap(find.text('Retry location'));
    await tester.pumpAndSettle();
    expect(find.text(_address), findsOneWidget);
    expect(calls, 2);
    expect(backend.calls, 1);
  });

  for (final supported in [true, false]) {
    testWidgets(
      'empty or unsupported address lookup keeps GPS, supported: $supported',
      (tester) async {
        final service = EvidenceLocationService(
          supported: supported,
          lookup: (_, _, _) async => [],
        );
        await _mount(tester, service, _Backend());
        await tester.pumpAndSettle();
        expect(
          find.text(
            supported
                ? 'No address found. Coordinates are shown below.'
                : 'Address lookup is unavailable on this platform. Coordinates are shown below.',
          ),
          findsOneWidget,
        );
        _expectOriginalEvidence(tester);
      },
    );
  }

  testWidgets('evidence backend errors retain the original retry flow', (
    tester,
  ) async {
    final backend = _Backend()..fail = true;
    var lookups = 0;
    final service = EvidenceLocationService(
      supported: true,
      lookup: (_, _, _) async {
        lookups++;
        return [_place];
      },
    );
    await _mount(tester, service, backend);
    await tester.pumpAndSettle();
    expect(find.text('Exception: Evidence unavailable'), findsOneWidget);
    expect(lookups, 0);
    backend.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_address), findsOneWidget);
    expect(backend.calls, 2);
  });

  for (final coordinates in <(Object?, Object?)>[
    (91.0, 74.3587),
    (null, 74.3587),
    (31.5204, 'invalid'),
  ]) {
    testWidgets(
      'invalid evidence coordinates $coordinates remain visible without a lookup',
      (tester) async {
        var lookups = 0;
        final service = EvidenceLocationService(
          supported: true,
          lookup: (_, _, _) async {
            lookups++;
            return [_place];
          },
        );
        final backend = _Backend()
          ..latitude = coordinates.$1
          ..longitude = coordinates.$2;
        await _mount(tester, service, backend);
        await tester.pumpAndSettle();
        expect(
          find.text('Invalid coordinates. Saved values are shown below.'),
          findsOneWidget,
        );
        expect(find.text('Latitude: ${coordinates.$1}'), findsOneWidget);
        expect(find.text('Longitude: ${coordinates.$2}'), findsOneWidget);
        expect(find.text('Retry location'), findsNothing);
        expect(lookups, 0);
      },
    );
  }

  testWidgets(
    'device locale overrides English UI fallback and reloads only for an effective change',
    (tester) async {
      final requested = <Locale>[];
      final service = EvidenceLocationService(
        supported: true,
        lookup: (_, _, locale) async {
          requested.add(locale);
          return [Placemark(locality: locale.toLanguageTag())];
        },
      );
      final backend = _Backend();
      await _mount(
        tester,
        service,
        backend,
        deviceLocale: const Locale('ur', 'PK'),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(
          tester.element(find.text('Location')),
        ).languageCode,
        'en',
      );
      expect(requested, [const Locale('ur', 'PK')]);
      expect(find.text('ur-PK'), findsOneWidget);

      tester.platformDispatcher.localesTestValue = [const Locale('fr', 'CA')];
      await tester.pumpAndSettle();
      expect(requested, [const Locale('ur', 'PK'), const Locale('fr', 'CA')]);
      expect(find.text('fr-CA'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [
        const Locale('fr', 'CA'),
        const Locale('ur', 'PK'),
      ];
      await tester.pumpAndSettle();
      expect(requested.length, 2);
      tester.platformDispatcher.localesTestValue = [const Locale('ur', 'PK')];
      await tester.pumpAndSettle();
      expect(find.text('ur-PK'), findsOneWidget);
      expect(
        requested.length,
        2,
      ); // Reuse the existing locale-keyed cache entry.
      expect(backend.calls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      tester.platformDispatcher.localesTestValue = [const Locale('de')];
      await tester.pump();
      expect(requested.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an in-flight previous locale cannot replace the current address',
    (tester) async {
      final english = Completer<List<Placemark>>();
      final urdu = Completer<List<Placemark>>();
      final requested = <Locale>[];
      final service = EvidenceLocationService(
        supported: true,
        lookup: (_, _, locale) {
          requested.add(locale);
          return locale.languageCode == 'en' ? english.future : urdu.future;
        },
      );
      await _mount(tester, service, _Backend());
      await tester.pump();
      tester.platformDispatcher.localesTestValue = [const Locale('ur', 'PK')];
      await tester.pump();
      english.complete([const Placemark(locality: 'Previous locale address')]);
      await tester.pump();
      expect(find.text('Previous locale address'), findsNothing);
      expect(requested, [const Locale('en'), const Locale('ur', 'PK')]);
      urdu.complete([const Placemark(locality: 'Current locale address')]);
      await tester.pumpAndSettle();
      expect(find.text('Current locale address'), findsOneWidget);
      expect(find.text('Previous locale address'), findsNothing);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'readable evidence fits ${brightness.name}, wide/narrow and 2x text',
      (tester) async {
        final service = EvidenceLocationService(
          supported: true,
          lookup: (_, _, _) async => [_place],
        );
        await _mount(tester, service, _Backend(), brightness: brightness);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(AttendanceEvidenceScreen),
          matchesGoldenFile('goldens/evidence_location_${brightness.name}.png'),
        );
        for (final width in [320.0, 800.0]) {
          tester.view.physicalSize = Size(width, 700);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(_address));
          expect(find.text(_address), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('dismissal during geocoding does not update disposed widgets', (
    tester,
  ) async {
    final pending = Completer<List<Placemark>>();
    final service = EvidenceLocationService(
      supported: true,
      lookup: (_, _, _) => pending.future,
    );
    await _mount(tester, service, _Backend());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    pending.complete([_place]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _expectOriginalEvidence(WidgetTester tester) {
  expect(find.byType(Image), findsOneWidget);
  expect(find.text(_record.timestamp.toString()), findsOneWidget);
  expect(find.text('Latitude: 31.5204'), findsOneWidget);
  expect(find.text('Longitude: 74.3587'), findsOneWidget);
  expect(find.text('Accuracy: 8.0 m'), findsOneWidget);
  expect(find.text('Sample Android device'), findsOneWidget);
}

Future<void> _mount(
  WidgetTester tester,
  EvidenceLocationService service,
  _Backend backend, {
  Brightness brightness = Brightness.light,
  Locale deviceLocale = const Locale('en'),
}) async {
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider.value(value: service),
        ChangeNotifierProvider(create: (_) => AuthProvider(backend: backend)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: AttendanceEvidenceScreen(record: _record),
      ),
    ),
  );
}

class _Backend extends PreviewCompanyBackend {
  int calls = 0;
  bool fail = false;
  Object? latitude = 31.5204;
  Object? longitude = 74.3587;
  @override
  Future<Map<String, dynamic>> evidence(String recordId) async {
    calls++;
    if (fail) throw Exception('Evidence unavailable');
    return {
      'photo_url': 'https://example.invalid/photo.jpg',
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': 8.0,
    };
  }
}
