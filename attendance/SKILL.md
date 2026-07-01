# SKILL — Technical Skills & Patterns for This Codebase

Purpose: document the essential technical knowledge required to work effectively in this Flutter attendance app. Covers domain-specific patterns, security considerations, and debugging techniques.

## 1) Core Flutter & Dart Requirements

- **Provider state management** (v6.1.5): understand `ChangeNotifier`, `MultiProvider`, `Consumer` patterns. See `lib/main.dart` for setup and `lib/providers/auth_provider.dart` for example.
- **Async/await & Futures**: heavy use of async operations (permissions, location, network). Understand error propagation and `Future.delayed()` for simulating async calls.
- **Error handling**: exceptions are caught, stripped of "Exception: " prefix, and displayed in UI. See `auth_provider.dart::login()` (line 86).
- **Widget lifecycle**: `initState`, `TickerProviderStateMixin` for animations (see `attendance_screen.dart` pulse/success animations, lines 28-72).

## 2) Domain-Specific Skills: Geofencing & Anti-Cheat

### Geofence validation (attendance_provider.dart::attemptCheckIn)
- Retrieve office location (latitude, longitude, radiusInMeters)
- Call `LocationService.getVerifiedLocation()` to get user's proven real position
- Calculate distance with `Geolocator.distanceBetween()`
- Reject if distance > office.radiusInMeters
- **Critical**: do NOT bypass anti-cheat or geofence checks; these are security boundaries

### Anti-cheat location verification (location_service.dart::getVerifiedLocation)
- Enforce high accuracy GPS: `LocationAccuracy.high`
- **Reject mocked locations**: check `position.isMocked == true` and throw exception (line 38)
- **Accuracy threshold**: reject if `position.accuracy > 100` meters (line 43)
- Request/check permissions at lines 16-27 before fetching position
- This is a critical control point — never skip these checks

## 3) Camera & SOAP Workflow

### Image capture flow (attendance_screen.dart::_handleCheckIn)
1. Request camera permission via `permission_handler` (line 79)
2. Use `ImagePicker` to capture from front camera, 70% quality (lines 96-100)
3. Convert image to base64 string
4. Create SOAP XML payload with employee ID, timestamp, base64 image
5. POST to backend via `MobileAttendanceService.submit()` (lib/services/mobile_attendance_service.dart)

### SOAP service (mobile_attendance_service.dart)
- Constructs raw SOAP XML request body
- POST to configured endpoint with base64-encoded image
- Handles SOAP-specific response format
- Any changes to request payload must be made here, not in screens

## 4) State Management & Provider Patterns

### Provider initialization (lib/main.dart)
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => AttendanceProvider()),
    // ... other providers
  ],
  child: const AttendanceApp(),
)
```

### Reading state in screens
```dart
final provider = context.read<AuthProvider>();  // one-time read
final user = context.watch<AuthProvider>().currentUser;  // rebuild on change
```

### Updating state
- Modify provider properties and call `notifyListeners()` (see auth_provider.dart line 49, 82)
- For complex updates, prefer transactional patterns: set loading, try operation, handle error, update state, notify (see attendance_provider.dart::attemptCheckIn lines 41-84)

### Optimistic UI pattern (attendance_history_provider.dart::markAttendanceNow)
1. Insert optimistic local record immediately
2. Trigger `notifyListeners()` to update UI
3. Submit to backend in background
4. On failure: rollback local record, notify UI with error
- This pattern ensures responsive UI even on slow networks

## 5) Persistence & SharedPreferences

### Storing user data
- User ID persisted to SharedPreferences on login (auth_provider.dart line 80)
- User-specific data keyed as `${userId}_fieldName` (lines 71-72, 102-103)
- Always await SharedPreferences async methods

### Storing office location
- Office coordinates cached in LocalStorageService (local_storage_service.dart)
- Falls back to hardcoded defaults if not cached
- Updated via `OfficeService.updateOfficeLocation()` → `LocalStorageService.saveOfficeLocation()`

### Pattern: provider initialization checks persisted state
```dart
AuthProvider constructor → _checkLoginStatus() → look for userId in prefs → restore user if found
```

## 6) Testing Approaches

### Widget tests (test/widget_test.dart)
- Use `WidgetTester` to pump widgets and simulate user interactions
- Wrap tests in `testWidgets()` block
- Call `await tester.pump()` or `await tester.pumpWidget()` to trigger frame rendering
- Use `expect(find.byIcon(...), findsOneWidget)` to assert UI state

### Mock data patterns (currently used)
- Services like `employees_service.dart`, `attendance_service.dart`, `device_service.dart` return hardcoded mock data
- Replace mock implementations with real API calls when integrating backend
- Maintain same method signatures to avoid changing consumers

### Testing providers
- Create providers with injected mock services (see auth_provider.dart constructor, line 15-18)
- Use `ChangeNotifierProvider` in test harness with mock EmployeeService
- Call provider methods and assert state changes via `notifyListeners()`

## 7) Common Debugging Techniques

### Location mocking detection
- On emulator: ensure "Mock Location" app or developer settings are OFF before testing geofence
- Desktop emulator in Android Studio: set mock location in Extended Controls
- If `position.isMocked == true` throws, user is running Fake GPS app — guide them to disable it

### Permission issues
- Camera permission must be "Allow" (not "Allow once") for production use
- Location permission in Android: check AndroidManifest.xml for `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- iOS: check Info.plist for `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`
- Use `adb logcat` to see permission denial messages

### SOAP request debugging
- Log raw XML payload before POST (add to mobile_attendance_service.dart if needed)
- Check backend logs for malformed SOAP structure (namespace, element names)
- Verify base64 encoding: image must be valid image bytes, not corrupted

### Animation/UI hangs
- Excessive `notifyListeners()` calls can cause frame drops — batch state updates
- Ensure `TickerProviderStateMixin` providers (like pulse animation in attendance_screen.dart) are disposed properly
- Use Flutter DevTools Performance view to profile frame drops

## 8) Security & Anti-Cheat Considerations

### GPS spoofing protection
- Enforce `position.isMocked == false` (location_service.dart line 38) — this is non-negotiable
- Require high accuracy: reject `accuracy > 100` meters
- Consider time-of-day patterns: flag unusual attendance times in logs
- Never trust client-side timestamps alone; backend must validate submission time

### Image submission integrity
- Verify image is valid JPEG/PNG before base64 encoding
- Check file size on client (reject >5MB) to avoid network overhead
- Backend should validate image format and dimensions on receipt
- Consider image metadata (EXIF) for tampering detection

### Token & credential handling
- API keys/tokens in `api.md` must be treated as secrets — rotate before production
- Never log full tokens; log only last 4 characters
- Use environment variables or secure key storage (Android Keystore, iOS Keychain) for production

### Database & SQLite
- App imports sqflite (pubspec.yaml line 45) but currently uses SharedPreferences for user state
- If migrating to SQLite, encrypt sensitive fields (location, attendance records)
- Index frequently-queried fields (employee_id, attendance_date)

## 9) Performance Optimizations

### Location accuracy vs battery
- `LocationAccuracy.high` is appropriate for geofence checks but drains battery
- For mobile app in production, consider `LocationAccuracy.medium` and accept ~50m accuracy threshold if business allows
- Cache office location to avoid repeated fetches (see office_service.dart line 32)

### Image compression
- ImagePicker configured with `imageQuality: 70` (attendance_screen.dart line 99) to reduce payload
- Further reduce via JPEG compression in backend or use image resizing on client

### Provider watch vs read
- Use `context.watch<Provider>()` only when UI should rebuild on state change
- Use `context.read<Provider>()` for one-time operations (button tap handlers) to avoid unnecessary rebuilds

## 10) Extending the Codebase

### Adding a new feature
1. **Define model** in `lib/models/` (use copyWith, equality operators)
2. **Create service** in `lib/services/` to fetch/submit data (start with mock, replace later)
3. **Create provider** in `lib/providers/` using ChangeNotifier pattern; inject service in constructor
4. **Create screen** in `lib/screens/` consuming the provider via Consumer/read/watch
5. **Add route/navigation** in `lib/screens/app_shell.dart` if adding new page

### Adding a new permission
- Declare in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`
- Request at runtime using `permission_handler` plugin
- Handle denied/denied forever cases with user-friendly messages (see location_service.dart lines 18-27)

### Modifying SOAP payload
- Edit `mobile_attendance_service.dart` only
- Update XML structure and field mappings
- Test with mock backend (log raw POST body)
- Notify backend team of schema changes

## 11) Code Quality Standards

- **Null safety**: use `?` for nullable types, `!` only after null checks
- **Final variables**: use `final` for local variables to prevent accidental reassignment
- **Error messages**: strip "Exception: " prefix before displaying to user (e.g., auth_provider.dart line 86)
- **Dispose resources**: dispose AnimationControllers, StreamSubscriptions, etc. in dispose() method
- **Linting**: check `analysis_options.yaml` for enabled/disabled rules; run `flutter analyze` before commit

## 12) Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | MultiProvider setup, app entry |
| `lib/app.dart` | MaterialApp theming & navigation |
| `lib/providers/auth_provider.dart` | User authentication & persistence |
| `lib/providers/attendance_provider.dart` | Check-in geofence logic |
| `lib/providers/attendance_history_provider.dart` | Optimistic UI pattern |
| `lib/services/location_service.dart` | GPS retrieval, anti-cheat checks |
| `lib/services/mobile_attendance_service.dart` | SOAP client |
| `lib/screens/home/attendance_screen.dart` | Main check-in flow |
| `lib/config/app_theme.dart` | Theme, colors |
| `pubspec.yaml` | Dependencies: provider, geolocator, image_picker, permission_handler |

## 13) Gotchas & Common Pitfalls

- **Mocked location testing**: Easy to accidentally test with mock location enabled; always check Android settings
- **Stale UI state**: Forgetting to call `notifyListeners()` after state changes leads to stale UI
- **Network delays**: Tests using `Future.delayed()` simulate async calls; real backend calls may be slower/fail differently
- **Permissions not requested**: Camera/location permissions must be explicitly requested at runtime, not just declared
- **Image picker cancellation**: User canceling camera capture returns null — handle gracefully in _handleCheckIn
- **Geofence boundary edge cases**: Distance calculation subject to GPS noise (~5-10m); avoid radius < 20m for practical geofence

## Quick Skills Checklist

- [ ] Understand Provider pattern & ChangeNotifier
- [ ] Know how to read/write SharedPreferences asynchronously
- [ ] Understand geofence distance calculation & anti-cheat GPS validation
- [ ] Can trace camera → base64 → SOAP flow end-to-end
- [ ] Know how to handle runtime permissions (camera, location)
- [ ] Can debug location mocking issues
- [ ] Familiar with widget testing via WidgetTester
- [ ] Understand optimistic UI & rollback patterns
- [ ] Know security boundaries (do not bypass anti-cheat checks)
- [ ] Can extend codebase by adding new service → provider → screen

