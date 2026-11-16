# P Attendance

The Flutter application for P Attendance: multi-office attendance, photo/GPS
check-ins, attendance history, and office-specific admin tools.

See the [project README](../README.md) for the current feature overview, design
inspiration, and preview gallery. New mockups and a demo video will replace the
earlier interface previews when they are ready.

## Run The Demo

From this directory, with a Flutter SDK compatible with Dart `^3.11.4`:

```sh
flutter pub get
flutter run
```

Choose **Explore demo** on the sign-in screen. It is a read-only sample experience
with no company account, camera permission, location request, or upload required.

Real company access requires an invitation and backend configuration. Use the
[backend setup guide](docs/backend-setup.md) for your own Supabase deployment.

## Validate

```sh
flutter analyze
flutter test
```

## Build Android

```sh
flutter build apk --release --split-per-abi --target-platform android-arm64
```

The unconfigured build supports the demo. Live-build configuration is documented
in the setup guide. Physical-device acceptance and iOS verification remain
ongoing.
