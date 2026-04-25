# Attendance App: Simplified Folder Structure

## Architecture Overview

This project uses **Simple Organized Architecture** for a small 30-user app:

```
Flat organization with clear separation
├── services/        (API, storage, location)
├── models/          (data classes)
├── providers/       (state management with Provider)
├── screens/         (full pages)
├── widgets/         (reusable UI components)
└── config/          (theme, constants)
```

This approach is:
- **Lean**: No unnecessary abstractions
- **Fast to build**: Get features done quickly
- **But still organized**: Easy to find things
- **Easy to maintain**: Simple code is easier to understand

---

## Complete Folder Structure (Simplified)

```
lib/
├── config/
│   ├── constants.dart               # API URLs, timeouts, app settings
│   └── app_theme.dart               # Theme, colors, text styles
│
├── services/                        # Core functionality (API, storage, location)
│   ├── api_client.dart              # HTTP wrapper with auth headers
│   ├── local_storage.dart           # Encrypted SharedPreferences
│   ├── device_service.dart          # Get device ID, model, OS version
│   ├── location_service.dart        # GPS location requests
│   └── network_info.dart            # Check internet connectivity
│
├── models/                          # Data classes (DTOs)
│   ├── auth_model.dart              # Login response, user data
│   └── attendance_model.dart        # Attendance record
│
├── providers/                       # State Management (Provider)
│   ├── auth_provider.dart           # Login, logout, token management
│   └── attendance_provider.dart     # Mark attendance, offline records
│
├── screens/                         # Full pages
│   ├── login_screen.dart            # Employee login UI
│   └── attendance_screen.dart       # Mark attendance UI
│
├── widgets/                         # Reusable UI components
│   ├── location_widget.dart         # Display location info
│   ├── device_info_widget.dart      # Display device ID
│   └── error_message_widget.dart    # Show errors
│
├── main.dart                        # App entry point
└── app.dart                         # App widget setup (routing, theme, providers)
```

**Total files: ~15-20 (vs 50+ in enterprise version)**

---

## Detailed Folder Explanations

### 📁 `/config/`
**Purpose**: App-wide settings

**Files:**
- `constants.dart`: API base URL, timeouts, app settings
- `app_theme.dart`: Material theme, colors, typography

**Why here**: One place for all global config

---

### 📁 `/services/`
**Purpose**: Core business logic (API, storage, device access)

**Key Files:**
- `api_client.dart`: Wrapper around `http` package
  - Adds auth token to requests
  - Handles errors
  - Centralized logging
  
- `local_storage.dart`: Encrypted `SharedPreferences`
  - Store tokens securely
  - Simple key-value interface
  
- `device_service.dart`: Get device info
  - Device ID (android_id)
  - Device model, OS version
  
- `location_service.dart`: GPS access
  - Request permission
  - Get current location
  - Validate accuracy
  
- `network_info.dart`: Check internet

**Why**: Single source of truth; easy to mock for testing

---

### 📁 `/models/`
**Purpose**: Data classes (DTOs + Entities combined)

**Files:**
- `auth_model.dart`: Login response, user data
```dart
class User {
  final String id;
  final String name;
  final String thumbnail;
  final String accessToken;
  final String refreshToken;
}
```

- `attendance_model.dart`: Attendance record
```dart
class AttendanceRecord {
  final String employeeId;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
}
```

**Why**: Single combined model keeps things simple

---

### 📁 `/providers/`
**Purpose**: State Management with Provider

**Files:**
- `auth_provider.dart`: Login, logout, token refresh
```dart
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  Future<void> login(String id, String password) async {
    // Login logic
  }
  
  Future<void> logout() async {
    // Logout logic
  }
}
```

- `attendance_provider.dart`: Mark attendance, handle offline
```dart
class AttendanceProvider extends ChangeNotifier {
  List<AttendanceRecord> _bufferedRecords = [];
  bool _isLoading = false;
  
  Future<void> markAttendance() async {
    // Mark attendance
  }
  
  Future<void> syncBuffered() async {
    // Sync offline records
  }
}
```

**Why**: Provider handles all state; simple to use

---

### 📁 `/screens/`
**Purpose**: Full page UIs

- `login_screen.dart`: Employee login
- `attendance_screen.dart`: Mark attendance

**Simple rule**: One screen = one file

---

### 📁 `/widgets/`
**Purpose**: Reusable UI components

- `location_widget.dart`: Show location info
- `device_info_widget.dart`: Show device ID
- `error_message_widget.dart`: Display errors

**Why**: Reusable, keep screens clean

---

### 📁 `/main.dart`
Entry point, runs the app

### 📁 `/app.dart`
Sets up MaterialApp, providers, routing

## Why This Structure Works for Small Apps (30 Users)

### ✅ Simplicity
1. **Flat Organization**: No deep nesting, easy to find files
2. **Fewer Files**: ~15 files vs 50+ in enterprise version
3. **Fast Understanding**: New developer can grasp structure in 5 minutes

### ✅ Maintainability  
1. **Clear Responsibilities**: Services do business logic, providers manage state
2. **Easy to Debug**: Small codebase, easier to trace issues
3. **Quick Changes**: Modify a feature without touching 10 other files

### ✅ Testability
1. **Mockable Services**: Easy to mock `api_client.dart` for testing
2. **Provider Testing**: Test providers independently
3. **Simple Test Setup**: Less configuration needed

### ✅ Flexibility
1. **Can Expand**: If app grows, convert a `/service` into a full `/feature/` folder
2. **Not Over-Engineered**: No unnecessary abstractions for small scale

## Simple Data Flow (For 30-User App)

```
Screen (UI)
    ↓ Uses
Provider (State Management)
    ↓ Calls
Services (API, Storage, Location)
    ↓ Returns to
Models (Data Classes)
    ↓ Back to
Provider & Screen Updates
```

**Rule**: Providers are the connection between screens and services

---

## Added Files Beyond Structure

### `/lib/main.dart`
```dart
void main() {
  runApp(const MyApp());
}
```
**Entry point**

### `/lib/app.dart`
```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        title: 'Attendance App',
        theme: AppTheme.lightTheme,
        home: Consumer<AuthProvider>(
          builder: (_, auth, __) {
            return auth.user != null ? AttendanceScreen() : LoginScreen();
          },
        ),
      ),
    );
  }
}
```
**Initializes providers and routing**


---

## File Naming Conventions

| What | Convention | Example |
|------|-----------|---------|
| Dart Files | `snake_case.dart` | `auth_provider.dart` |
| Classes | `PascalCase` | `class AuthProvider` |
| Variables/Functions | `camelCase` | `isLoggedIn`, `markAttendance()` |
| Providers | `*_provider.dart` | `auth_provider.dart` |
| Models | `*_model.dart` | `auth_model.dart` |
| Services | `*_service.dart` | `device_service.dart` |
| Screens | `*_screen.dart` | `login_screen.dart` |
| Widgets | `*_widget.dart` | `location_widget.dart` |

---

## Imports Best Practice

**DO:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/services/api_client.dart';
import 'package:attendance_app/providers/auth_provider.dart';
```

**DON'T:**
```dart
import 'package:attendance_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:attendance_app/services/api_client.dart';
```
**Reason**: External packages first, then local imports

---

## Common Patterns in This Structure

### Provider Pattern (State Management)
```dart
class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final LocalStorage _storage;
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Methods
  Future<void> login(String id, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final user = await _apiClient.login(id, password);
      await _storage.saveToken(user.accessToken);
      _user = user;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### Service Pattern (Business Logic)
```dart
class ApiClient {
  Future<User> login(String id, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      body: {'employee_id': id, 'password': password},
    );
    
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Login failed');
    }
  }
}
```

### Model Pattern (Data Classes)
```dart
class User {
  final String id;
  final String name;
  final String thumbprint;
  final String accessToken;
  final String refreshToken;
  
  User({
    required this.id,
    required this.name,
    required this.thumbprint,
    required this.accessToken,
    required this.refreshToken,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['employee_id'],
      name: json['name'],
      thumbprint: json['thumbprint'],
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}
```

### Widget Pattern (Reusable UI)
```dart
class LocationWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double accuracy;
  
  const LocationWidget({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Latitude: $latitude'),
        Text('Longitude: $longitude'),
        Text('Accuracy: ${accuracy.toStringAsFixed(2)}m'),
      ],
    );
  }
}
```

---

## Setup Instructions

Create the folder structure in `lib/`:

```bash
# From project root
mkdir -p lib/config
mkdir -p lib/services
mkdir -p lib/models
mkdir -p lib/providers
mkdir -p lib/screens
mkdir -p lib/widgets

# Then create the files (start with empty stubs)
touch lib/config/constants.dart
touch lib/config/app_theme.dart
touch lib/services/api_client.dart
touch lib/services/local_storage.dart
touch lib/services/device_service.dart
touch lib/services/location_service.dart
touch lib/services/network_info.dart
touch lib/models/auth_model.dart
touch lib/models/attendance_model.dart
touch lib/providers/auth_provider.dart
touch lib/providers/attendance_provider.dart
touch lib/screens/login_screen.dart
touch lib/screens/attendance_screen.dart
touch lib/widgets/location_widget.dart
touch lib/widgets/device_info_widget.dart
touch lib/widgets/error_message_widget.dart
```

**Total**: 15 Dart files for the entire app

