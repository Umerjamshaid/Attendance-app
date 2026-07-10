# P Attendance

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-111111?style=for-the-badge)

P Attendance is a clean Flutter attendance app for mobile teams and portfolio demos. It focuses on fast check-ins, history tracking, admin visibility, profile management, and privacy-oriented screens.

## Preview

<table>
  <tr>
    <td align="center"><img src="screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%201.png" width="260" alt="Attendance home screen"></td>
    <td align="center"><img src="screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%202.png" width="260" alt="Attendance history screen"></td>
    <td align="center"><img src="screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%203.png" width="260" alt="Admin dashboard screen"></td>
  </tr>
  <tr>
    <td align="center"><strong>Attendance</strong></td>
    <td align="center"><strong>History</strong></td>
    <td align="center"><strong>Admin</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%204.png" width="260" alt="Profile screen"></td>
    <td align="center"><img src="screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%205.png" width="260" alt="Settings screen"></td>
    <td align="center"><img src="screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%206.png" width="260" alt="Privacy policy screen"></td>
  </tr>
  <tr>
    <td align="center"><strong>Profile</strong></td>
    <td align="center"><strong>Settings</strong></td>
    <td align="center"><strong>Privacy</strong></td>
  </tr>
</table>

## Highlights

- Mobile-first attendance check-in flow
- GPS-aware validation before check-in
- Attendance history and summary views
- Admin dashboard for team oversight
- Profile, settings, and privacy screens
- SharedPreferences-backed local app state

## Tech Stack

- Flutter
- Dart
- Provider
- Geolocator
- image_picker
- permission_handler
- shared_preferences
- Google Fonts

## Run Locally

```powershell
flutter pub get
flutter run
```

## Build

```powershell
flutter build apk --debug
```

## Notes

- This repository is kept public and portfolio-friendly.
- The screenshots in this README live inside the repo so GitHub can render them directly.
- No private backend details are included here.
