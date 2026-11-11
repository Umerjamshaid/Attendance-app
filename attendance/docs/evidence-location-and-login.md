# Evidence Location And Login Refresh

Implemented on 2026-11-11, using the supplied `block-analysis.md` as design
reference. This work preserves the existing Provider architecture, authentication,
attendance verification, submission payloads, history, and Admin dashboard layout.

## Reverse-Geocoding Choice

| Approach | Benefits | Tradeoffs | Decision |
| --- | --- | --- | --- |
| [geocoding](https://pub.dev/packages/geocoding) | Native Android/iOS services; no new API key; structured placemarks and per-call locale | Provider availability, completeness and rate limits vary; no web/Windows adapter | Selected |
| [geocode](https://pub.dev/packages/geocode) | Dart HTTP wrapper with broader platform coverage | Additional geocode.xyz dependency, quotas and service policy | Not added |
| [geocoder2](https://pub.dev/packages/geocoder2) | Structured Google Geocoding API results | Requires a Google API key and enabled service; a server integration would be preferable to shipping a new key | Not added |

The app uses `geocoding` 5.0.1. Its Android adapter is explicitly constrained to
5.0.0, whose native build uses AGP 8 rather than the AGP 9 configuration declared
by adapter 5.1.0. This avoids an unrelated Android toolchain migration. The lockfile
also records `geocoding_platform_interface` 5.0.0 and `geocoding_darwin` 1.0.3.
The adapter's Android minimum is API 24, matching this Flutter SDK's app minimum;
compile SDK 36 is already configured. Darwin's iOS minimum is 12, below the app's
declared iOS 13 target. An actual iOS build still requires verification on macOS.

Sources: [package API](https://pub.dev/documentation/geocoding/5.0.1/geocoding/Geocoding/placemarkFromCoordinates.html)
and [placemark components](https://pub.dev/documentation/geocoding/5.0.1/geocoding/Placemark-class.html).

## Evidence Behavior

- A new Location section resolves the coordinates returned by the authorized
  evidence endpoint. It does not request the viewer's current GPS position.
- The photo, timestamp, latitude, longitude, accuracy and device strings are
  unchanged. Address loading/failure never hides or blocks these fields.
- Labels use supplied components from one candidate: name, street, neighborhood,
  city, district, province, postal code and country when available. Empty and
  repeated components are omitted. Numeric coordinate-like names are not treated
  as addresses. Components from different candidates are never merged.
- Loading, no-result, unsupported-platform, invalid-coordinate and temporary-error
  states are explicit. Retry location retries only the address request.
- Address language follows the platform's primary preferred locale, independent
  of the English UI fallback. Runtime locale changes reload the label and reuse
  the existing locale-keyed cache; the observer is removed when the view closes.
- An existing evidence Retry callback returned a Future from `setState`; it now
  creates the request separately and assigns it in a synchronous state callback.
  The same endpoint, record ID and original retry text are retained.

### Request Management And Privacy

- Cache keys use exact coordinates and locale; coordinates are not rounded into
  neighboring properties. Matching pending requests share one Future.
- At most 64 completed entries are retained using least-recently-used eviction.
  Successful labels expire after 24 hours; failures/no-result entries after 30
  seconds. Explicit retry bypasses the completed-entry cooldown.
- Native calls are serialized. Each request has an eight-second UI timeout,
  including queue time. A timeout cannot cancel native platform work, so its
  slot stays occupied until that work actually ends. Expired queued requests
  are skipped; late results cannot replace a timeout result or refill its cache.
- Provider owns the service inside the existing account/backend scope. Sign-out
  or account replacement disposes the cache and completes pending UI requests.
  No new address or coordinate data is written to SharedPreferences or disk.
- The OS geocoder may use network-backed Apple/Android location services. No
  additional third-party HTTP provider or API credential is configured here.

### Historical Consistency

The saved coordinates remain the authoritative evidence. Address text is a
best-effort display label resolved at viewing time, not a verified street address
or an immutable historical snapshot. Provider labels can change between sessions.

Storing an address permanently should be a separate server-side change: nullable
address/components, provider and language, resolution timestamp, write-once
enrichment for a saved record, existing organization access rules, and the same
retention/deletion policy as location evidence. Geocoding failure must not reject
a valid check-in. A phone-derived label should not silently become trusted
attendance evidence. No schema, edge-function or live backend changes were made.

## Buzz Principles Applied

- Kept Provider for application state. Animations use local controllers and do
  not publish per-frame updates to authentication/attendance providers.
- Added shared layout, bundled typography and motion tokens. Existing Profile
  aliases retain their values, preserving the established screens.
- Login uses DM Sans, semantic theme colors, 8dp bordered fields/buttons,
  restrained heading weights, 16dp input text and 13dp supporting text.
- Added a password visibility toggle and explicit email-to-password keyboard
  focus. Autofill hints are grouped. Public Login does not autofocus over its
  alternative demo option; the existing single employee-ID form still does.
- Kept the existing validation messages, credentials, sign-in serialization,
  Provider callbacks, demo option, password recovery and navigation.
- Short fade/slide entrance and state crossfades respect reduced motion, even
  when that setting changes during entrance.
- Shared spring press feedback is used by Login's action and navigation icons.
  It uses an unbounded controller, preserves release velocity, leaves layout
  and hit areas unchanged, retains the stable child, and stops offscreen.
- Existing swipe/page spring values are centralized without changing their
  behavior. The employee sheet's specialized spring route stays intact.
- Tabler remains the common icon font. Added only eye/eye-off glyph aliases.
  `flutter_svg`, Rive, Hooks and Riverpod were evaluated but are not necessary
  for these assets/interactions. No new font or illustration asset was added.

## File Map

| Files | Purpose |
| --- | --- |
| `pubspec.yaml`, `pubspec.lock` | Geocoding dependency and compatible Android adapter pin |
| `lib/services/evidence_location_service.dart` | Formatting, cache, queue, timeouts and session disposal |
| `lib/bootstrap.dart` | Account-scoped service injection |
| `lib/screens/admin/attendance_evidence_screen.dart` | Location states and synchronous evidence Retry callback |
| `lib/config/ui_tokens.dart` | Shared layout, typography and motion roles |
| `lib/config/app_theme.dart` | Consistent default field borders, colors and label/error styles |
| `lib/config/app_icons.dart` | Password visibility icon aliases |
| `lib/screens/login/login_screen.dart` | Login styling, keyboard/autofill, password visibility and local motion |
| `lib/widgets/spring_scale.dart` | Reusable spring-only press response |
| `lib/widgets/bottom_nav.dart`, `lib/screens/app_shell.dart` | Reuse motion tokens; retain dock geometry and synchronized swipes |
| `lib/widgets/user-profile/profile_section_card.dart` | Existing Profile tokens delegate to the shared definitions |
| `test/evidence_location_service_test.dart` | Formatting, partial/Unicode results, cache, queue, cooldown, timeout and disposal |
| `test/attendance_evidence_location_test.dart` | Original fields, loading/errors/retry, lifecycle and responsive evidence |
| `test/public_login_design_test.dart` | Company Login visuals, credentials, recovery, focus and accessibility settings |
| `test/spring_scale_test.dart` | Settling, reduced motion, ticker lifecycle, stable children/layout and hit testing |
| `test/goldens/login_*.png` | Updated existing employee-ID Login references |
| `test/goldens/company_login_*.png`, `test/goldens/evidence_location_*.png` | New light/dark reference images |
| `docs/ui-handoff.md`, this document | Durable scope, decisions and verification record |

## Verification

`flutter analyze --no-pub` reports no issues. All 119 Flutter tests pass,
including existing authentication, history, media,
navigation and attendance UI tests. The 12 existing non-Login golden images match
the previous palette build byte-for-byte. New Login/evidence light/dark renders
were inspected; tests cover 320dp, wide layouts, keyboard insets and 2x text.
The evidence image in the test fixture deliberately exercises the existing photo
failure fallback, not a real employee photo.

Private source hashes are unchanged. No real employee location/photo was sent
during tests and no live attendance was submitted. Review fixes were published
to PR #18 as 4adbc47. A dedicated public-only CodeRabbit CLI review of that
commit completed with zero findings, and all four original threads are resolved.
The GitHub bot's automatic review was separately rate-limited (neutral/skipped)
at publication; this was not a compiler or test failure.
Native address accuracy/network behavior and physical camera/GPS uploads still
need testing on a phone. iOS native compilation has not been verified here.

The public ARM64 release build from review-fix source 4adbc47 succeeds with the
pinned native adapter. It
replaces the previous APK at
`.dart_tool/public-verification/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
Size: 21,400,859 bytes (approximately 20.4 MB). SHA-256:
`08096EFBF755A6284953A6A44F7E09846A13EB5F98C9253CB50A0637D2F9FD6E`.
All isolated public Dart sources matched the tested working files. Packaged new
address/Login markers and the bundled font are present; private integration and
fixture-address markers are absent. Private source hashes match their previous
values. Existing Gradle/AGP/Kotlin future-compatibility warnings remain.

The APK still uses the existing debug signing configuration in release mode and
the shared application ID. It is a test artifact, not a production-signed store
release, and installing it can replace the currently installed public/private app.
