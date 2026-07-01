# AGENTS — Project Guide for AI Coding Agents

Purpose: quick, actionable orientation so an AI agent can be productive immediately in this Flutter attendance app.

1) Big picture
- Flutter mobile app (Android + iOS) with MaterialApp entry in `lib/app.dart` and app bootstrap in `lib/main.dart`.
- State management: River/Provider-style patterns implemented with custom providers under `lib/providers/` (e.g. `auth_provider.dart`, `attendance_provider.dart`, `attendance_history_provider.dart`). Agents should treat providers as the surface API for app logic.
- Services layer: `lib/services/` contains platform & backend integration (e.g. `mobile_attendance_service.dart` — SOAP image submission; `location_service.dart` — permission, anti-cheat checks; `local_storage_service.dart` — SharedPreferences wrappers). Prefer editing services for integration changes and providers for business logic.
- UI shells & screens: `lib/screens/` holds feature screens. Entry UI is `lib/screens/app_shell.dart` which composes pages (Attendance, History, Admin conditional, Profile) and bottom navigation.

2) Key patterns & examples (do not change without tests)
- Providers persist small data to SharedPreferences. See `auth_provider.dart` (stores token) and `local_storage_service.dart` (office coordinates).
- Optimistic UI: `attendance_history_provider.dart::markAttendanceNow` inserts a local record then submits to backend (rollback on failure). Mirror this pattern when adding new operations.
- Geofence & anti-cheat: `location_service.dart::getVerifiedLocation` checks `isMocked` and `accuracy` before approving a location — do not bypass this check.
- Camera -> SOAP flow: `attendance_screen.dart` captures image with ImagePicker, converts to base64 and sends to `MobileAttendanceService.submit` which constructs a SOAP POST. Changes to payload must be made in `lib/services/mobile_attendance_service.dart`.

3) Build / run / test workflows (PowerShell examples)
- Install deps and run on connected device/emulator:
```powershell
flutter pub get;
flutter run -d <device-id>
```
- Build APK (debug/release):
```powershell
flutter build apk --debug; # or --release
```
- Run unit/widget tests:
```powershell
flutter test
```
- When working with native Android Gradle tasks (Windows):
```powershell
cd android; .\gradlew.bat assembleDebug; cd ..
```

4) Integration points & external dependencies
- SOAP backend used by `lib/services/mobile_attendance_service.dart` (constructs raw XML and POST). Search for "MobileAttendance" to find related calls.
- Uses device/location/camera plugins (check `pubspec.yaml` for exact packages). Location accuracy and mocked-location checks are enforced in `location_service.dart`.
- Local persistence: `SharedPreferences` via `local_storage_service.dart`.

5) Conventions & small gotchas
- Minimal mocking/stubs: many services return mock data (see `attendance_service.dart`, `employees_service.dart`). Before integrating a real backend, locate and replace these stubs.
- Sensitive token: `api.md` contains a value that looks like a key on line 1 — treat as secret; do NOT commit or echo it in public outputs. Remove or rotate before publishing.
- Prefer changing service implementations over directly mutating providers for external integration changes.
- Admin tab is conditionally shown in `app_shell.dart` — altering role checks affects navigation and tests.

6) Helpful file map (start here)
- `pubspec.yaml` — dependencies and SDK constraints
- `lib/main.dart`, `lib/app.dart` — app bootstrap and routing
- `lib/providers/*.dart` — business logic & state
- `lib/services/*.dart` — backend/native integrations
- `lib/screens/*` — UI and flows (notably `screens/home/attendance_screen.dart`)
- `lib/config/*` — theme, tokens and constants
- `test/widget_test.dart` — an example widget test

If you need changes implemented (fixes, tests, or feature work), tell me the target area (service, provider, screen) and I'll make minimal, tested edits following these patterns.

