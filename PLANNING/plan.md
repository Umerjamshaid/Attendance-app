# Attendance App: Project Plan & Phases

## Executive Summary
This attendance app will be built in 5 progressive phases, designed to be production-ready and scalable to 1000+ employees. Each phase builds on the previous, with clear testing criteria before moving forward.

---

## Phase Breakdown

### PHASE 0: Project Setup & Foundation (Days 1-2)
**Goal**: Create a solid, production-ready project base

**Tasks:**
- [ ] Create blank Flutter project
- [ ] Add dependencies to pubspec.yaml:
  - `http: ^1.1.0` (API calls)
  - `geolocator: ^9.0.0` (location)
  - `android_id: ^0.0.4` (device ID)
  - `encrypted_shared_preferences: ^5.0.0` (secure token storage)
  - `provider: ^6.0.0` (state management)
  - `google_maps_flutter: ^2.5.0` (optional: show location on map)
  - `intl: ^0.19.0` (date formatting)
  
- [ ] Setup folder structure (see structure.md)
- [ ] Create base models & DTOs
- [ ] Create service layer interfaces
- [ ] Setup error handling framework
- [ ] Create mock data for testing

**Deliverables:**
- Clean project structure
- All dependencies resolved
- Base models defined
- Documentation of folder structure

**Success Criteria:**
- `flutter pub get` runs without errors
- Folder structure matches plan
- Models compile without warnings

---

### PHASE 1: Authentication System (Days 3-5)
**Goal**: Implement secure login with token management

**Components:**
1. **AuthService** (handles API authentication)
   - Login endpoint call
   - Error handling for invalid credentials / API failures
   - Status code handling (401, 403, etc.)

2. **TokenStorage** (manages secure token storage)
   - Store access token (encrypted)
   - Store refresh token (encrypted + more secure)
   - Retrieve tokens with validation
   - Clear tokens on logout
   - Track token expiration

3. **AuthProvider** (Provider for state management)
   - Track login state (LoggedIn / LoggedOut / Loading)
   - Current employee info
   - Handle token refresh
   - Expose login/logout methods
   - Handle session expiration

4. **LoginScreen** (UI)
   - Employee ID input
   - Password input
   - Error message display
   - Loading state
   - Navigate to attendance screen on success

**API Contract Expected:**
```
POST /api/auth/login
Request: { employee_id, password }
Response: { 
  access_token, 
  refresh_token, 
  employee_id, 
  name,
  expires_in_minutes 
}
Status: 200 (success), 401 (invalid), 500 (server error)
```

```
POST /api/auth/refresh
Request: { refresh_token }
Response: { access_token, expires_in_minutes }
Status: 200 (success), 401 (token expired), 500 (error)
```

**Testing:**
- [ ] Unit tests: Token storage (encrypt/decrypt)
- [ ] Unit tests: AuthProvider (state transitions)
- [ ] Widget tests: LoginScreen (input validation, error display)
- [ ] Integration tests: Login flow with mock API
- [ ] Edge case: Invalid token format
- [ ] Edge case: Token expiry during app usage

**Deliverables:**
- LoginScreen UI (functional, not styled)
- AuthService + AuthProvider
- TokenStorage implementation
- Tests passing (>80% coverage)
- Error handling for all auth failures

**Success Criteria:**
- User can login with valid credentials
- Invalid credentials show error message
- Tokens stored securely
- Token refresh works automatically
- Logout clears tokens

---

### PHASE 2: Attendance Module (Days 6-9)
**Goal**: Implement attendance marking with location & device tracking

**Components:**
1. **LocationService** (handles GPS tracking)
   - Request location permission
   - Get current location (lat/long)
   - Validate location accuracy
   - Handle permission denied
   - Handle GPS disabled
   - Get altitude/speed if available

2. **DeviceService** (handles device identification)
   - Get device ID (android_id / iOS equivalent)
   - Get device model, OS version
   - Get app signature/version

3. **AttendanceService** (business logic)
   - Validate all required data available
   - Create attendance record (device ID + location + timestamp)
   - Submit to backend API
   - Handle offline mode (buffer locally)
   - Implement retry logic with exponential backoff

4. **AttendanceProvider** (state management)
   - Current attendance state (NotMarked / Loading / Success / Failed)
   - Last marked timestamp
   - Buffered records (for offline)
   - Expose markAttendance() method
   - Handle sync of buffered records

5. **AttendanceScreen** (UI)
   - Display employee info
   - Display current location (map + coordinates)
   - Display device ID (for verification)
   - Display current timestamp
   - "Mark Attendance" button
   - Show last marked time
   - Show success/error message
   - Show buffered records count

**API Contract Expected:**
```
POST /api/attendance/mark
Headers: { Authorization: "Bearer {access_token}" }

Client sends (Flutter app captures all):
{
  "employee_id": "EMP001",              # From login response
  "device_id": "a1b2c3d4e5f6g7h8",      # Flutter captures (android_id)
  "latitude": 40.7128,                  # Flutter captures (GPS)
  "longitude": -74.0060,                # Flutter captures (GPS)
  "accuracy_meters": 15.5,              # Flutter captures (GPS accuracy)
  "timestamp": "2025-04-04T09:15:30Z"   # Flutter captures (device time)
}

API action:
→ Receives data from Flutter app
→ Validates authorization (token check)
→ Saves all data to SQL Server database
→ Generates server_timestamp (official mark time)

Response (201 Created):
{
  "success": true,
  "marked_at": "2025-04-04T09:15:33Z",  # SQL Server timestamp (official)
  "message": "Attendance marked successfully"
}

Status: 201 (created), 400 (invalid data), 401 (unauthorized), 409 (duplicate), 500 (error)
```

**Offline Buffering Strategy:**
```
1. User marks attendance (offline or online)
2. Create local record with unique ID
3. Try to send to API
4. If fails: Save to local database/storage with status "pending"
5. On network restored: Retry all pending records
6. Mark as synced when API succeeds
7. Show user which records are pending/synced
```

**Location Validation:**
- [ ] Accuracy check (must be <=50m ideally)
- [ ] Timeout if location not acquired in 30 seconds
- [ ] Allow user to retry if accuracy poor
- [ ] Warn user if accuracy >100m

**Testing:**
- [ ] Unit tests: LocationService (mock location)
- [ ] Unit tests: DeviceService (device info retrieval)
- [ ] Unit tests: AttendanceProvider (offline buffering)
- [ ] Widget tests: AttendanceScreen (UI interactions)
- [ ] Integration tests: Full attendance flow (mock API + mock location)
- [ ] Edge case: Location permission denied
- [ ] Edge case: GPS disabled
- [ ] Edge case: Network error (offline)
- [ ] Edge case: Multiple back-to-back attempts
- [ ] Edge case: Poor GPS accuracy

**Deliverables:**
- AttendanceScreen UI (functional)
- All services implemented
- Offline buffering working
- Tests passing
- Documentation of offline strategy

**Success Criteria:**
- User can mark attendance with location
- Location captured accurately
- Offline data buffered and synced
- Error messages clear
- Rate limiting enforced (client-side: max 1 per minute)

---

### PHASE 3: UI/UX Polish & Error Handling (Days 10-12)
**Goal**: Professional UI, excellent error handling, user guidance

**Components:**
1. **Navigation Setup**
   - LoginScreen → AttendanceScreen
   - Logout → LoginScreen
   - Handle expired tokens (redirect to login)

2. **Error Handling Improvements**
   - Show specific, actionable error messages
   - Network error → offline icon + retry button
   - Location denied → settings link to enable permission
   - GPS disabled → settings link to enable GPS
   - Rate limit → show countdown
   - Token expired → auto-refresh or redirect to login

3. **Feedback & Status**
   - Loading indicators (spinners, skeletons)
   - Success animations
   - Toast notifications or snackbars
   - Progress indicators

4. **Accessibility**
   - Semantic labels for screen readers
   - Sufficient contrast ratios
   - Touch target sizes (48x48 dp minimum)
   - Alternative text for images

5. **Responsive Design**
   - Tablet support
   - Portrait/landscape orientation
   - Different screen sizes

6. **Settings/Debug Screen (optional but helpful)**
   - Show current token status
   - Show device ID & model
   - Show app version
   - Clear tokens (force logout)
   - View local logs

**Testing:**
- [ ] Widget tests: All screens
- [ ] Integration tests: Full user flows
- [ ] Accessibility tests: Screen reader compatibility
- [ ] Device tests: Portrait/landscape, different sizes

**Deliverables:**
- Polished UI
- Comprehensive error handling
- Navigation working smoothly
- Accessibility basics met

**Success Criteria:**
- App looks professional
- Error messages are helpful
- Navigation is intuitive
- No crashes on common error scenarios

---

### PHASE 4: Testing & Validation (Days 13-14)
**Goal**: Comprehensive testing before production release

**Test Coverage:**
- [ ] Unit tests (targets: 80%+ code coverage)
  - Auth logic, token management
  - Location validation
  - Data formatting
  - Error handling
  
- [ ] Widget tests (all screens, user interactions)
  
- [ ] Integration tests
  - Login → Attendance marking flows
  - Offline to online sync
  - Token refresh mid-flow
  
- [ ] Manual E2E tests
  - Real device: Full login to attendance cycle
  - Test offline behavior
  - Test poor network
  - Test location errors

**Performance Testing:**
- [ ] App startup time (<3 seconds)
- [ ] Location acquisition time (<10 seconds)
- [ ] API response time (<5 seconds)
- [ ] Memory usage (baseline)
- [ ] Battery impact (GPS polling)

**Security Validation:**
- [ ] Tokens not exposed in logs
- [ ] Tokens properly encrypted in storage
- [ ] No hardcoded credentials
- [ ] API communication over HTTPS
- [ ] Certificate validation working

**Regression Testing:**
- [ ] User can still login after multiple logouts
- [ ] Concurrent API requests handled correctly
- [ ] Data not corrupted on app restart
- [ ] Buffered records persist on app restart

**Deliverables:**
- Test reports (unit, widget, integration)
- Performance baseline
- Security audit checklist
- Bugs found & fixed

**Success Criteria:**
- >80% code coverage
- All E2E tests passing
- No memory leaks
- Performance acceptable
- No security issues

---

### PHASE 5: Production Hardening & Deployment (Days 15-16)
**Goal**: Ready for production with monitoring & rollout plan

**Tasks:**
- [ ] Remove debug logging from production builds
- [ ] Setup crash reporting (Firebase Crashlytics optional)
- [ ] Setup performance monitoring
- [ ] Create release build (both APK/AAB for Android)
- [ ] Test release build thoroughly
- [ ] Document deployment process
- [ ] Create user documentation/onboarding
- [ ] Setup backend monitoring
- [ ] Create runbooks for common issues

**Documentation:**
- [ ] User guide (photos, step-by-step)
- [ ] Admin guide (manual adjustments, troubleshooting)
- [ ] Developer guide (architecture, adding features)
- [ ] API documentation (for backend team reference)
- [ ] Deployment guide

**Deliverables:**
- Release-ready app
- Complete documentation
- Monitoring setup
- Deployment checklist

**Success Criteria:**
- App builds without errors
- Release build tested on real devices
- Documentation complete
- Monitoring configured
- Deploy runbook created

---

## Module Responsibilities Matrix

| Module | Responsibility | Depends On |
|--------|-----------------|-----------|
| **AuthService** | Authenticate user via API, handle errors | None |
| **TokenStorage** | Secure token encryption/decryption | None |
| **AuthProvider** | Manage login state, coordinate auth | AuthService, TokenStorage |
| **LocationService** | Request permission, get GPS data | Android/iOS integration |
| **DeviceService** | Get device identifiers & info | Android/iOS integration |
| **AttendanceService** | Attendance business logic, API submission | AuthService, LocationService, DeviceService |
| **AttendanceProvider** | Manage attendance state, handle offline sync | AttendanceService |
| **LocalStorage** | Persist buffered attendance records | None |
| **ApiClient** | HTTP requests with auth headers, error handling | TokenStorage, AuthProvider |
| **ErrorHandler** | Centralized error processing & messaging | None |
| **UI Layer** | Display state, capture user input | All providers |

---

## Key Milestones

| Date | Milestone | Criteria |
|------|-----------|----------|
| Day 2 | Project foundation complete | Folder structure, dependencies, models done |
| Day 5 | Authentication working | Login/logout, token refresh, tests passing |
| Day 9 | Attendance marking functional | Location capture, API submit, offline sync |
| Day 12 | UI polished | Professional look, error handling, navigation smooth |
| Day 14 | Testing complete | 80%+ coverage, E2E tests passing, no crashes |
| Day 16 | Production ready | Release build tested, all docs done, deployment ready |

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| GPS acquisition fails | Medium | High | Timeout handling, retry UX, queue system |
| Token expiry during session | Low | Medium | Auto-refresh, concurrent request handling |
| Network failures | Medium | Medium | Offline buffering, retry logic, clear messaging |
| Poor location accuracy | Low | Medium | Warn user, validate on backend, manual override |
| API rate limiting | Low | Low | Client-side throttling, batch requests |
| Scaling to 1000 employees | Medium | High | Distribute marking over time window, database indexing |

---

## Definition of Done (Per Phase)

✅ **Code complete** (no TODOs in critical paths)
✅ **Tests written & passing** (>80% coverage for that module)
✅ **Code reviewed** (logic is sound, conventions followed)
✅ **Documentation updated** (code comments, API docs)
✅ **Integration tested** (works with other modules)
✅ **No P1 bugs** (uses priority/severity system)
✅ **Performance acceptable** (benchmarks met)

---

## Glossary & API Terms

- **Access Token**: Short-lived token (15-30 min) for API requests
- **Refresh Token**: Long-lived token (7-30 days) for obtaining new access tokens
- **Geofencing**: Backend validation that location is within allowed zone
- **Idempotent**: API request produces same result if called multiple times
- **Offline Buffering**: Storing failed requests locally for later sync
- **Exponential Backoff**: Retry delays increase: 1s → 2s → 4s → 8s, etc.
- **PII**: Personally Identifiable Information (employee names, location)
- **Rate Limiting**: Max requests per time period (e.g., 1 per minute)

