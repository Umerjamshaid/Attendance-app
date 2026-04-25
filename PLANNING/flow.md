# Attendance App: User Flows & State Management

## High-Level State Diagram

```
┌─────────────────┐
│   App Start     │
└────────┬────────┘
         │
         ▼
    ┌────────────┐
    │ Has Token? │
    └─┬──────┬───┘
      │      │
    YES     NO
      │      │
      ▼      ▼
  ┌──────┐ ┌──────────┐
  │Login │ │Login     │
  │Done  │ │Screen    │
  └──────┘ └─┬──────┬─┘
             │      │
          Login  Retry
          Fail   Later
             │      │
             ▼      ▼
          Error  Loading
          Show   Show
```

---

## FLOW 1: Login Flow (Cold Start)

### Happy Path
```
1. App launches
   → Check if token exists in secure storage
   → No token found
   
2. Show LoginScreen
   ├─ Input: Employee ID field
   ├─ Input: Password field
   ├─ Button: "Login"
   
3. User enters credentials & taps Login
   → Enable: Loading spinner
   → Disable: All inputs
   → AuthProvider.login(id, password) called
   
4. LoginUseCase validates inputs
   Condition: ID & password not empty?
   ├─ YES → Continue
   ├─ NO → Show error "Please fill all fields"
   
5. AuthRemoteDatasource.login() called via ApiClient
   HTTP: POST /api/auth/login
   Body: { employee_id, password }
   Timeout: 30 seconds
   
6. Backend validates credentials
   Response: {
     access_token: "eyJhbGciOi...",
     refresh_token: "eyJhbGciOi...",
     employee_id: "EMP001",
     name: "John Doe",
     expires_in_minutes: 30
   }
   
7. Tokens stored securely
   → AccessToken: In-memory + encrypted storage (15-30 min expiry)
   → RefreshToken: Encrypted storage (7-30 day expiry)
   
8. AuthProvider updates state
   → isLoggedIn = true
   → currentEmployee = { id: "EMP001", name: "John Doe" }
   → notifyListeners()
   
9. UI rebuilds
   → LoginScreen → AttendanceScreen (automatic navigation)
   
10. AttendanceScreen displays
    ├─ Employee name: "John Doe"
    ├─ Button: "Mark Attendance"
    ├─ Current time: "2025-04-04 09:15 AM"
    └─ Status: "Ready to mark attendance"

TOTAL TIME: ~3-5 seconds (including network + storage)
```

### Error Path: Invalid Credentials
```
3. User enters WRONG password, taps Login
   
5. ApiClient makes request
   
6. Backend returns 401 Unauthorized
   { error: "Invalid employee credentials" }
   
7. AuthRemoteDatasource catches error
   → Throws UnauthorizedFailure("Invalid employee ID or password")
   
8. LoginUseCase catches failure
   → Returns Left(UnauthorizedFailure(...))
   
9. AuthProvider catches failure
   → isLoggedIn = false
   → errorMessage = "Invalid employee ID or password"
   → notifyListeners()
   
10. UI shows error
    → Red SnackBar: "Invalid employee ID or password"
    → LoginScreen remains, inputs enabled
    → User can retry
```

### Error Path: Network Error
```
3. User enters credentials, taps Login
   → Device is OFFLINE
   
5. ApiClient tries POST /api/auth/login
   → Network timeout (30 seconds)
   → SocketException: "Network unreachable"
   
7. AuthRemoteDatasource catches SocketException
   → Throws NetworkFailure("No internet connection")
   
8. LoginUseCase catches failure
   → Returns Left(NetworkFailure(...))
   
9. AuthProvider catches failure
   → isLoggedIn = false
   → errorMessage = "No internet connection. Check your network."
   → notifyListeners()
   
10. UI shows error
    → Red SnackBar with retry button
    → User can tap "Retry" or reconnect and tap Login again
```

### Error Path: Server Error
```
6. Backend returns 500 Internal Server Error
   { error: "Database connection failed" }
   
7. AuthRemoteDatasource catches 500
   → Throws ServerFailure("Server error. Try again later.")
   
9. AuthProvider catches failure
   → errorMessage = "Service temporarily unavailable. Try again later."
   
10. UI shows error message
    → User is prompted to retry in a few minutes
```

### Security: Brute Force Prevention
```
Backend should implement:
- Maximum 5 failed login attempts in 15 minutes
- After 5 failures: Account locked for 30 minutes
- Each attempt logged with timestamp + IP

Client should:
- NOT retry infinitely automatically
- Disable login button after 3 failed attempts
- Show message: "Too many failed attempts. Try again in 15 minutes."
- Clear error message after timeout or next successful attempt
```

---

## FLOW 2: Attendance Marking (Main Feature)

### Happy Path: Mark Attendance
```
1. AttendanceScreen displayed
   ├─ Show: Employee name
   ├─ Show: "Mark Attendance" button (enabled)
   ├─ Show: Last marked time (if any)
   └─ Show: "Ready" status

2. User taps "Mark Attendance"
   → Button: Disabled (show spinner)
   → Status: "Getting location..."
   
3. LocationService.getCurrentLocation() called
   → Request permission IF first time
   ├─ User grants permission: Continue
   ├─ User denies permission: See "Permission Denied" branch
   
4. GPS acquires location (up to 30 second timeout)
   → Multiple attempts with increasing timeout
   ├─ Attempt 1 (5 sec): High accuracy requested
   ├─ Attempt 2 (10 sec): Normal accuracy
   ├─ Attempt 3 (15 sec): Any accuracy
   
5. Location obtained
   {
     latitude: 40.7128,
     longitude: -74.0060,
     accuracy: 15.5,       // meters
     timestamp: 2025-04-04T09:15:30Z
   }
   
6. Accuracy validation
   Condition: accuracy <= 50 meters?
   ├─ YES → Continue (OK accuracy)
   ├─ NO → Show warning: "Location accuracy is poor (85m). Mark anyway?"
           → User can: [Retry] [Mark Anyway] [Cancel]

7. If accuracy poor & user taps Retry
   → Go back to step 3 (request GPS again)
   → Max retries: 3

8. If accuracy poor & user taps Mark Anyway
   → Continue (user accepts lower accuracy)
   → Note: Backend will flag this for review

9. Device info collected
   → DeviceService.getDeviceInfo()
   {
     device_id: "a1b2c3d4e5f6g7h8",    (android_id)
     model: "Samsung Galaxy A12",
     os_version: "12.0.1",
     app_version: "1.0.0"
   }

10. Create attendance record
    {
      employee_id: "EMP001",
      device_id: "a1b2c3d4e5f6g7h8",
      latitude: 40.7128,
      longitude: -74.0060,
      accuracy_meters: 15.5,
      timestamp: "2025-04-04T09:15:30Z",
      request_id: "uuid-12345"    // For idempotency
    }

11. AttendanceProvider calls AttendanceService.markAttendance()
    → Save record to local storage with status: "pending"
    → Attempt to submit to API

12. Flutter app sends to API
    POST /api/attendance/mark
    Headers: { Authorization: "Bearer {access_token}" }
    Body: {
      "employee_id": "EMP001",           # From backend login
      "device_id": "a1b2c3d4e5f6g7h8",   # Flutter captured (android_id)
      "latitude": 40.7128,               # Flutter captured (GPS)
      "longitude": -74.0060,             # Flutter captured (GPS)
      "accuracy_meters": 15.5,           # Flutter captured (GPS)
      "timestamp": "2025-04-04T09:15:30Z" # Flutter captured (device time)
    }

13. Backend API receives & processes
    → Validates: Authorization token valid?
    → Saves to SQL Server database:
      ├─ employee_id (identifies employee)
      ├─ device_id (identifies which device)
      ├─ latitude/longitude (location from Flutter)
      ├─ accuracy_meters (GPS accuracy from Flutter)
      ├─ client_timestamp (device time from Flutter)
      └─ server_timestamp (NOW - official attendance time)

14. Backend API responds (201 Created)
    Response: {
      "success": true,
      "marked_at": "2025-04-04T09:15:33Z",  # SQL Server timestamp (official)
      "message": "Attendance marked successfully"
    }

15. AttendanceProvider updates state
    → Mark local record as "synced"
    → Update lastMarkedTime
    → successMessage = "Attendance marked successfully!"
    → Clear any previous errors
    → notifyListeners()

16. UI updates
    → Hide spinner
    → Show success message (green toast: "Attendance marked!")
    → Button: Re-enabled
    → Show updated "Last marked: 09:15 AM"
    → Optional: Show confirmation (time, location, device ID)

17. User can see buffered records
    ├─ Display: "Offline records: 2 pending, 1 synced"
    └─ (For debugging purposes)

TOTAL TIME: ~15-30 seconds (GPS acquisition is slowest)
```

### Detailed Step: Location Permission Handling
```
First Time Ever?
├─ YES → Show native permission dialog
│   ├─ User taps "Allow": Permission granted, proceed
│   ├─ User taps "Don't Allow": Go to "Permission Denied" path
│   ├─ User taps "Ask Later": Show dialog later, cancel for now
│
├─ NO → Check if permission already granted
    ├─ YES → Use existing permission, proceed
    └─ NO → Show in-app explanation
        "We need location to mark your attendance"
        [Settings] [Cancel]
        ├─ User taps "Settings": Open app settings
        ├─ User taps "Cancel": Cancel attendance marking
```

### Error Path: Location Permission Denied
```
3. User denies location permission
   
4. LocationService throws LocationPermissionFailure
   
5. AttendanceProvider catches error
   → state = "Failed"
   → errorMessage = "Location permission required. Please enable in settings."
   → notifyListeners()

6. UI shows error
   → Red SnackBar: "Location permission denied"
   → [Open Settings] [Cancel] buttons
   → If user taps "Open Settings": Navigate to app settings page
   → Button: Re-enabled for retry
```

### Error Path: GPS Disabled
```
3. LocationService checks: Is GPS enabled?
   → Device GPS is OFF
   
4. LocationService throws LocationServiceDisabledFailure
   
5. AttendanceProvider catches error
   → errorMessage = "GPS is disabled. Please turn on location services."
   
6. UI shows error
   → [Open Settings] [Try Again] [Cancel]
```

### Error Path: GPS Timeout
```
3-4. LocationService waits for GPS signal
    → 30 seconds pass, no GPS lock
    → Timeout triggered
    
5. LocationService throws LocationTimeoutFailure
   
7. AttendanceProvider catches error
   → errorMessage = "Could not get location. Check GPS signal."
   
8. UI shows error
   → [Retry] [Cancel]
   → User can: Retry (start over), or Cancel (don't mark attendance)
```

### Error Path: Network Error During Submission
```
11-12. Local record saved, attempting to submit to API
        → Device goes OFFLINE after GPS was captured
        → Network timeout
        
13. ApiClient throws NetworkFailure
    
15. AttendanceProvider catches error
    → Mark record status: "pending_sync" (not synced to server)
    → errorMessage = "Could not submit to server. Will retry when online."
    → notifyListeners()

16. UI shows error + reassurance
    → Yellow SnackBar: "Offline. Your attendance will sync when online."
    → Button: Re-enabled
    → Show: "Buffered records: 1 pending"

17. Background sync mechanism
    → App periodically checks: Is device online?
    → On network restoration: Automatically retry pending records
    → Show progress: "Syncing buffered records..."
    → Show result: "All records synced!"
```

### Error Path: 401 Unauthorized (Token Expired)
```
12. ApiClient makes request with token
    → Response: 401 Unauthorized
    
13. ApiClient intercepts 401
    → Attempts to refresh token using refresh_token
    → POST /api/auth/refresh { refresh_token }
    
    If refresh succeeds:
    ├─ Get new access_token
    ├─ Store in secure storage
    ├─ Retry original attendance marking request
    ├─ Continue with normal flow
    
    If refresh fails (refresh_token also expired):
    ├─ Clear tokens
    ├─ Force logout
    ├─ Navigate to LoginScreen
    ├─ Show message: "Session expired. Please login again."
```

### Error Path: 409 Conflict (Duplicate Attendance)
```
13. Backend detects: Employee already marked today
    → Response: 409 Conflict
    { error: "Attendance already marked today at 08:45 AM" }
    
15. AttendanceProvider catches error
    → errorMessage = "Already marked today at 08:45 AM"
    → notifyListeners()

16. UI shows error
    → Red SnackBar: "Already marked today at 08:45 AM"
    → Button: Disabled for next 5 minutes (user feedback)
    → Show: Previous mark time
```

### Error Path: 400 Bad Request (Geofence Violation)
```
13. Backend validates location
    → User is 2 km away from office
    → Response: 400 Bad Request
    { error: "Location is outside allowed zone" }
    
15. AttendanceProvider catches error
    → errorMessage = "Location outside office bounds"
    → Show additional info: "You are 2 km away from office"
    → notifyListeners()

16. UI shows error
    → Red SnackBar with location details
    → User must physically move to office or use admin override
```

### Rate Limiting: Multiple Attempts
```
Scenario: User taps button 3 times rapidly

1st tap: Normal flow (see happy path)

2nd tap (while 1st is processing):
├─ Button is disabled (spinner showing)
├─ 2nd tap is ignored (no action)

3rd tap:
├─ Same as 2nd (no action)

Implementation:
├─ Set button disabled while loading
├─ Or: Client-side rate limiting (max 1 per minute)
├─ Backend: Rate limiting (max 5 per minute)
├─ On rate limit error: Show "Please wait before marking again"
```

---

## FLOW 3: Offline Attendance (Critical for Reliability)

### Scenario: User marks attendance while offline

```
1. User taps "Mark Attendance"

2-9. LocationService.getCurrentLocation()
   → GPS works (offline doesn't affect GPS)
   → Location obtained successfully

10-11. Create record, save to local storage
    {
      id: "uuid-12345",
      status: "pending",
      employee_id: "EMP001",
      device_id: "...",
      latitude: 40.7128,
      longitude: -74.0060,
      timestamp: "2025-04-04T09:15:30Z",
      created_at: "2025-04-04T09:15:30Z",
      synced_at: null
    }

12. Attempt to submit to API
    → Network check: Device is OFFLINE
    → Connection timeout after 10 seconds

13. Catch NetworkFailure
    → Record already in local storage (step 11 saved it)
    → Don't throw error; instead inform user of buffering

14-15. AttendanceProvider state
    {
      state: "Offline - Buffered",
      errorMessage: "You're offline. Attendance will sync when online.",
      bufferedRecords: [
        { id: "uuid-12345", status: "pending" }
      ]
    }

16. UI shows
    → Yellow banner: "Offline mode - Your attendance has been saved locally"
    → Show: "Buffered: 1 pending"
    → Button: Re-enabled (user can try again or wait)

17. User goes online
    → App detects network restored (via network_info service)
    → Automatically starts sync:
    
    POST /api/attendance/sync
    Body: {
      records: [
        {
          id: "uuid-12345",
          employee_id: "EMP001",
          device_id: "...",
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: "2025-04-04T09:15:30Z"
        }
      ]
    }
    
18. Backend processes sync
    → Validate each record
    → Insert into database
    → Return results
    {
      synced: [
        { id: "uuid-12345", success: true, marked_at: "2025-04-04T09:15:35Z" }
      ],
      failed: [],
      errors: []
    }

19. AttendanceProvider updates
    → Mark "uuid-12345" as synced
    → Clear from buffered list
    → Show success: "Buffered records synced!"
    → notifyListeners()

20. UI updates
    → Green banner: "Attendance synced!"
    → Hide buffered records
    → Show: "Last marked: 09:15 AM"
    → Back to normal state

OUTCOME: User attendance still recorded even during offline period
```

### Edge Case: Offline for Extended Period

```
Day 1: 9:15 AM - User offline, marks attendance locally
       20:00 PM - User comes online
       → Records synced successfully

Day 2: 9:00 AM - User checks app
       → App shows all previous records synced
       
BUT: What if sync permanently fails?
├─ Record stored locally for 7 days
├─ If sync still fails after 7 days: Delete with warning
├─ Show warning: "Offline record couldn't sync after 7 days"
├─ Employee should contact admin to manually mark attendance
```

### Conflict Resolution: Same Record Submitted Twice

```
Due to retry logic, same record might be submitted to backend twice:

Record A: id="uuid-12345", timestamp="2025-04-04T09:15:30Z"

Scenario:
1. First submission successful, but response is lost (network timeout during response)
2. Client thinks: "Submission failed"
3. Client retries: Submit Record A again

Backend receives same record twice:
→ Use request_id / record_id for idempotency
→ Check: If record with same id exists, return success (don't insert twice)
→ Return: { success: true, already_synced: true }

Client result: Record marked once, no duplication
```

---

## FLOW 4: Logout Flow

### Happy Path
```
1. User taps "Logout" button (in settings or menu)

2. AuthProvider.logout() called
   
3. TokenStorage.clearTokens()
   → Delete access token
   → Delete refresh token
   → Clear employee info
   
4. AuthProvider state
   {
     isLoggedIn: false,
     currentEmployee: null,
     tokens: null
   }
   → notifyListeners()

5. Buffered attendance records
   → Left in local storage (for manual review)
   → Or delete with confirmation: "Delete unsync records?"

6. UI navigates to LoginScreen
   → All inputs cleared
   → Ready for next login
   → Show message: "Logged out successfully"
```

### Automatic Logout: Session Expired

```
Scenario: App open for 8 hours, token expires (refresh token expired)

1. User taps "Mark Attendance"

2-12. API call attempts to use expired access token
      → 401 Unauthorized response

13. ApiClient tries to refresh token
    → Refresh token also expired
    → Refresh fails: 401 Unauthorized
    
14. ApiClient detects double 401
    → Force logout
    → Clear all tokens
    → Navigate to LoginScreen
    → Show message: "Session expired. Please login again."

15. User logs in again (normal login flow)
```

---

## FLOW 5: Token Refresh Mechanism

### Automatic Refresh
```
AccessToken expiration: 30 minutes

Scenario 1: API call with 5 minutes left on token
├─ Request made successfully
├─ Token still valid
└─ Continue normally

Scenario 2: API call with token expired 1 minute ago
├─ API returns 401 Unauthorized
├─ ApiClient intercepts 401
├─ Calls AuthProvider.refreshToken()
│  ├─ Uses refresh_token to get new access_token
│  ├─ POST /api/auth/refresh { refresh_token }
│  └─ Stores new access_token
├─ Retries original request with new token
├─ Request succeeds
└─ User doesn't notice the refresh

Scenario 3: Both tokens expired
├─ Refresh attempt fails (401)
├─ No valid token available
├─ Force logout (see Flow 4)
└─ User must login again
```

### Explicit Refresh (Before Expiry)

```
Optional: Check token expiry before critical operation

Before marking attendance:
├─ Check: Token expires in < 5 minutes?
├─ YES → Refresh token proactively
├─ NO → Use current token
├─ Success → Mark attendance with fresh token
```

---

## FLOW 6: Settings / Debug Screen (Optional)

### Display Current Status
```
Settings Screen shows:
├─ Logged In As: "John Doe (EMP001)"
├─ Token Status:
│   ├─ Access Token: Valid (expires in 24 min)
│   ├─ Refresh Token: Valid (expires in 6 days)
├─ Device Info:
│   ├─ Device ID: "a1b2c3d4e5f6g7h8"
│   ├─ Model: "Samsung Galaxy A12"
│   ├─ OS: Android 12.0.1
├─ App Version: 1.0.0 (Build 5)
├─ Buffered Records: 2 pending, 1 synced
├─ Last Sync: 2 minutes ago
├─ Logs:
│   └─ [View] [Clear] [Share] buttons
├─ Actions:
│   ├─ [Test Location] (mock GPS)
│   ├─ [Force Refresh Token]
│   ├─ [Clear Token] (force logout)
│   ├─ [Clear All Data] (factory reset)
│   └─ [Logout]
```

---

## State Management Summary (Provider)

### AuthProvider State
```dart
class AuthProvider extends ChangeNotifier {
  // State variables
  bool isLoggedIn = false;
  AuthEntity? currentEmployee;
  String? accessToken;
  String? refreshToken;
  bool isLoading = false;
  String? errorMessage;
  
  // Methods
  Future<void> login(String id, String password) async { }
  Future<void> logout() async { }
  Future<void> refreshToken() async { }
  Future<bool> isTokenValid() async { }
}
```

### AttendanceProvider State
```dart
class AttendanceProvider extends ChangeNotifier {
  // State variables
  AttendanceState state = AttendanceState.ready;
  DateTime? lastMarkedTime;
  List<BufferedAttendanceRecord> bufferedRecords = [];
  String? errorMessage;
  bool isLoading = false;
  
  // Methods
  Future<void> markAttendance() async { }
  Future<void> syncBufferedRecords() async { }
  void clearError() { }
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

## Error Handling Strategy (Centralized)

```
All errors follow this pattern:

Try → Catch NetworkFailure → Show: "No internet"
Try → Catch UnauthorizedFailure → Show: "Invalid login" OR Force logout
Try → Catch LocationFailure → Show: "Location error"
Try → Catch ServerFailure → Show: "Server error"
Try → Catch ValidationFailure → Show: "Invalid input"
Try → Catch GenericFailure → Show: "Unknown error"
```

---

## Summary: User Journey Timeline

```
⏱️ Cold Start (First Launch)
├─ 0s: App launches
├─ 1s: Check for existing token
├─ 2s: Show LoginScreen (token not found)
└─ Result: Ready for input

⏱️ Login
├─ 2s: User enters credentials
├─ 3s: User taps Login
├─ 5s: Network request
├─ 8s: Token stored
├─ 8s: Navigate to AttendanceScreen
└─ Result: Logged in, ready to mark

⏱️ Attendance Marking
├─ 8s: User taps "Mark Attendance"
├─ 10s: Request location permission (1st time)
├─ 15s: GPS acquiring (varies by location)
├─ 20s: Device info collected
├─ 22s: Submit to backend
├─ 24s: Success response
├─ 25s: UI updates
└─ Result: Attendance marked

⏱️ Total: ~25 seconds from launch to marked attendance
```

---

## Testing Scenarios

| Scenario | Test Category | Coverage |
|----------|--------------|---------|
| Valid login | Happy path | ✅ Must pass |
| Invalid password | Error handling | ✅ Must pass |
| Network offline during login | Offline mode | ✅ Must pass |
| Mark attendance online | Happy path | ✅ Must pass |
| Mark attendance offline | Offline sync | ✅ Must pass |
| Location permission denied | Permission handling | ✅ Must pass |
| GPS disabled | Error handling | ✅ Must pass |
| Token expired mid-request | Token refresh | ✅ Must pass |
| Duplicate attendance attempt | Validation | ✅ Must pass |
| Geofence violation | Location validation | ✅ Must pass |
| Rapid multiple taps | Race condition | ✅ Must pass |
| App crash with buffered data | Data persistence | ✅ Must pass |
| Resume app after 8 hours | Session management | ✅ Must pass |

