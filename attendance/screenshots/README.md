# Screenshot gallery

`current/` contains framed renders of the Flutter UI with fictional data.
The capture keeps the screen pixels intact and adds the presentation layout
around them. To refresh the root README gallery, run from `attendance/`:

```sh
flutter test --update-goldens --dart-define=ATTENDANCE_README_SCREENSHOTS=true tool/capture_site_screens_test.dart
```

Review the six images before publishing. The opt-in flag leaves the separate
website screenshots and older device mockups untouched.
