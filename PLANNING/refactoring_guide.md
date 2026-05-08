# 🛠️ Refactoring Guide: Cleaning Up Hardcoded Values

This guide explains how we refactored the `AttendanceScreen` to move away from hardcoded values and align with a professional, scalable architecture.

---

## 1. Identification of Hardcoded Values
Hardcoding data (like URLs, colors, or names) inside a widget makes it difficult to maintain and customize. We identified the following issues in the original `AttendanceScreen`:
- **Static Avatar URL**: Always showed "Alice Johnson".
- **Fixed Strings**: Labels like "Osquare" and "Browser" were static.
- **Mixed Theme Colors**: Used colors from different theme files instead of a unified design system.
- **Static Device Info**: Always sent "mobile" as the device type.

---

## 2. The Refactoring Strategy

### Step A: Service Layer Implementation
We first created/updated services to fetch real data instead of placeholders.
- **`DeviceService`**: Now provides the actual device model (e.g., "Android Device") and a unique device ID.
- **`OfficeService`**: Fetches office details (name, coordinates, radius) from the "backend" (mocked for now).

### Step B: Provider Enhancement
We updated `AttendanceProvider` to hold this dynamic data.
- Added `initialize()` to fetch device and office info when the screen loads.
- Added getters so the UI can read `deviceModel` and `officeLocation`.

### Step C: UI Unification (Design System)
We shifted the screen to use **`WC` tokens** (`wc_tokens.dart`) exclusively.
- **Benefit**: Changing `WC.present` in one file will now update the colors across the *entire app* (Login, History, and Attendance).
- **Consistency**: Ensures the app looks like a single cohesive product.

---

## 3. Implementation Steps for You to Learn

### 1. Dynamic UI with Provider
Instead of writing `'Osquare'`, we now use:
```dart
label: attendanceProvider.officeLocation?.name ?? 'Office'
```
This ensures that if the office name changes in the database, the app updates automatically without a code change.

### 2. Context-Aware Data
For the avatar, we use the user's name from the `AuthProvider`:
```dart
final avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.employeeName)}&background=000&color=fff&size=200';
```

### 3. Lifecycle Management
We use `WidgetsBinding.instance.addPostFrameCallback` in `initState` to trigger the data fetch:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<AttendanceProvider>().initialize();
  });
}
```
This is a standard pattern to perform asynchronous work immediately after the first frame is rendered.

---

## 4. Key Takeaways for Future Development
- **Never trust a string**: If it's a piece of data (like a name or a setting), it belongs in a **Service** or **Model**.
- **Follow the Token**: Always use your `config/` tokens for colors and spacing. If you need a new color, add it to the token file first.
- **Initialize Early**: Use your `Provider` to prepare data before the user needs to interact with it.

---

## 🎓 Your Next Challenge
Try to update the `OptionCard` for **GPS** to show the actual status (Enabled/Disabled) by creating a `LocationService` method that checks if GPS is turned on using a package like `geolocator`.
