---
name: "Implement Attendance Feature"
description: "Guide for implementing the attendance marking module following clean architecture + Provider pattern"
author: "Your Team"
created: "2025-04-04"
version: "1.0"
tags: ["flutter", "attendance", "feature-implementation", "provider"]
---

# Skill: Implement Attendance Feature

## Purpose
This skill guides you through implementing the attendance marking feature module following the project's clean architecture pattern and Provider state management.

**When to use this skill**: When implementing `features/attendance/` module (Phase 2)

---

## Architecture Pattern

The attendance feature follows Clean Architecture with 3 layers:

```
Presentation (UI)
    ↓ imports
Domain (Business Logic)
    ↓ imports
Data (Repositories & Datasources)
    ↓ imports
Core (Network, Services, Errors)
```

**Rule**: Never import upward (e.g., Data layer should NEVER import Presentation)

---

## Directory Structure

```
lib/features/attendance/
├── data/
│   ├── datasources/
│   │   ├── attendance_local_datasource.dart      # Local storage (buffering)
│   │   └── attendance_remote_datasource.dart     # API calls
│   ├── models/
│   │   ├── attendance_request.dart               # Request DTO
│   │   ├── attendance_response.dart              # Response DTO
│   │   └── buffered_attendance.dart              # For offline records
│   └── repositories/
│       └── attendance_repository_impl.dart
│
├── domain/
│   ├── entities/
│   │   └── attendance_entity.dart                # Core data
│   ├── repositories/
│   │   └── attendance_repository.dart            # Interface
│   └── usecases/
│       ├── mark_attendance_usecase.dart
│       ├── get_buffered_records_usecase.dart
│       └── sync_buffered_usecase.dart
│
└── presentation/
    ├── providers/
    │   └── attendance_provider.dart
    ├── screens/
    │   └── attendance_screen.dart
    └── widgets/
        ├── location_widget.dart
        ├── device_info_widget.dart
        ├── mark_button.dart
        └── buffered_records_widget.dart
```

---

## Implementation Checklist

### Step 1: Data Layer
- [ ] Create `AttendanceRemoteDatasource` (API calls to /api/attendance/mark)
- [ ] Create `AttendanceLocalDatasource` (store buffered records)
- [ ] Create request/response DTOs (RequestModel, ResponseModel)
- [ ] Create `AttendanceRepositoryImpl` (implements interface, handles online/offline logic)

### Step 2: Domain Layer
- [ ] Create `AttendanceEntity` (core data: employee_id, device_id, latitude, longitude, timestamp)
- [ ] Create `AttendanceRepository` interface
- [ ] Create `MarkAttendanceUseCase` (validates input, calls repository)
- [ ] Create `SyncBufferedUseCase` (retry pending records)

### Step 3: Presentation Layer
- [ ] Create `AttendanceProvider` (extends ChangeNotifier)
  - Properties: currentState, lastMarkedTime, bufferedRecords, errorMessage
  - Methods: markAttendance(), syncBuffered(), clearError()
- [ ] Create `AttendanceScreen` (UI that uses provider)
  - Show employee name, location, device ID
  - Button to mark attendance
  - Show buffered records count
- [ ] Create widgets: LocationWidget, DeviceInfoWidget, etc.

---

## Key Dependencies

Add to your AttendanceProvider constructor:

```dart
class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  final LocationService _locationService;
  final DeviceService _deviceService;
  
  AttendanceProvider({
    required AttendanceRepository repository,
    required LocationService locationService,
    required DeviceService deviceService,
  })
  : _repository = repository,
    _locationService = locationService,
    _deviceService = deviceService;
}
```

These should be provided via Provider setup in `app.dart` (dependency injection).

---

## Error Handling Pattern

Every operation should handle these failures:

```dart
Future<void> markAttendance() async {
  try {
    _isLoading = true;
    notifyListeners();
    
    // 1. Get location
    final location = await _locationService.getCurrentLocation();
    
    // 2. Get device info
    final deviceInfo = await _deviceService.getDeviceInfo();
    
    // 3. Submit
    final result = await _repository.markAttendance(
      AttendanceEntity(
        employeeId: _authProvider.currentEmployee.id,
        deviceId: deviceInfo.deviceId,
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
      ),
    );
    
    // Handle result (success or failure)
    
  } catch (e) {
    _errorMessage = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

## Testing Requirements

Before moving to Phase 3, ensure:

- [ ] Unit tests: `MarkAttendanceUseCase` (validate inputs)
- [ ] Unit tests: `AttendanceProvider` (state transitions)
- [ ] Unit tests: `SyncBufferedUseCase` (offline sync logic)
- [ ] Widget tests: `AttendanceScreen` (UI interactions)
- [ ] Integration tests: Full flow (mock API + location)
- [ ] Edge cases:
  - [ ] GPS disabled
  - [ ] Location permission denied
  - [ ] Network error during submission
  - [ ] Device already marked today
  - [ ] Multiple rapid mark attempts

---

## API Contract Expected

```
POST /api/attendance/mark
Headers: { Authorization: "Bearer {token}" }

Request Body:
{
  "employee_id": "EMP001",
  "device_id": "a1b2c3d4e5f6g7h8",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy_meters": 15.5,
  "timestamp": "2025-04-04T09:15:30Z"
}

Response (201 Created):
{
  "success": true,
  "marked_at": "2025-04-04T09:15:33Z",
  "message": "Attendance marked successfully"
}

Error Responses:
- 400: Invalid location/data
- 401: Unauthorized (token expired)
- 409: Already marked today
- 500: Server error
```

---

## Offline Buffering Strategy

When network fails:

1. Save record locally with `status: "pending"`
2. Show user: "You're offline. Attendance will sync when online."
3. On network restore: Automatically retry
4. Mark as `status: "synced"` when successful

Implementation:
- Use `LocalDatasource` to persist pending records
- Listen to network connectivity via `NetworkInfo` service
- Implement `SyncBufferedUseCase` to retry on network restore

---

## Success Criteria

This feature is complete when:

✅ User can mark attendance with location captured
✅ Offline records buffer and sync automatically
✅ All error messages are user-friendly
✅ Tests cover happy path + all error scenarios
✅ No UI freezes during GPS acquisition
✅ Buffered records visible in UI (for debugging)
✅ Rate limiting enforced (max 1 per minute, client-side)

---

## Common Mistakes to Avoid

❌ **Mistake**: Trusting device_id alone for verification
✅ **Fix**: Backend validates device_id + location + timestamp

❌ **Mistake**: Synchronous GPS calls blocking UI
✅ **Fix**: Use async/await, show loading spinner

❌ **Mistake**: Losing buffered records on app restart
✅ **Fix**: Persist to secure local storage before API attempt

❌ **Mistake**: Ignoring 401 responses during submission
✅ **Fix**: Let ApiClient auto-refresh token, then retry

❌ **Mistake**: No user feedback for buffering
✅ **Fix**: Show status: "Offline mode", "Syncing...", "Synced!"

---

## Reference Documentation

- **Flow Details**: See `PLANNING/flow.md` → **FLOW 2: Attendance Marking**
- **API Contract**: See `PLANNING/plan.md` → **Phase 2: API Contract Expected**
- **Offline Strategy**: See `PLANNING/flow.md` → **FLOW 3: Offline Attendance**
- **Architecture**: See `PLANNING/structure.md` → **Feature-Based Architecture**

---

## Example File Skeleton

### `attendance_provider.dart`
```dart
class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  final LocationService _locationService;
  final DeviceService _deviceService;
  
  AttendanceState _state = AttendanceState.ready;
  DateTime? _lastMarkedTime;
  List<BufferedAttendanceRecord> _bufferedRecords = [];
  String? _errorMessage;
  bool _isLoading = false;
  
  // Getters
  AttendanceState get state => _state;
  DateTime? get lastMarkedTime => _lastMarkedTime;
  List<BufferedAttendanceRecord> get bufferedRecords => _bufferedRecords;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  
  // Methods
  Future<void> markAttendance() async {
    // Implementation follows error handling pattern above
  }
  
  Future<void> syncBufferedRecords() async {
    // Retry pending records
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

enum AttendanceState {
  ready,
  loading,
  locationAcquiring,
  submitting,
  success,
  failed,
  offline,
  buffered,
}
```

---

## Resources & Links

- [Provider Documentation](https://pub.dev/packages/provider)
- [Geolocator Package](https://pub.dev/packages/geolocator)
- [Android ID Package](https://pub.dev/packages/android_id)
- Clean Architecture Concept: See `PLANNING/research.md` → Section 3.2