# Profile Gauge And Bloom Banner Colors - 2026-11-17

## Scope And Dependencies

- Local branch `codex/profile-gauge-bloom`, based on `c5d5ee4`. Earlier badge,
  History, search, tag and inline-delete prototypes remain intact.
- The user explicitly requested the published package. The final implementation
  uses actual `portal_labs: ^0.38.0` widgets, locked to **0.38.0**, not copied gauge
  or color-wheel implementations. The initial custom gauge draft was discarded.
- Local reference docs/source: `D:\work\APP flutter\portal-labs` version 0.38.0.
  After the user's clarification, no further web research was used.
- `path_provider` 2.1.6 was already installed transitively and is now a pinned
  direct dependency for persistent legacy color-banner files. No existing
  dependency versions were upgraded; Flutter/Dart constraints remain unchanged.

## Score Gauge

- `AttendanceScoreGauge` wraps the actual Portal `ScoreGauge`, including its
  spring, rotating ticks, odometer digits, settling arrow and label animation.
- Uses existing teal theme colors, Inter type and tabular numerals rather than
  introducing a rainbow palette or credit-score labels.
- Public/Profile activity uses existing `monthlyRate`; legacy/Profile overview
  uses existing `employee.attendanceRate`. No attendance calculations or employee
  ratings change. Existing day counts, check-in totals, streaks and legacy
  present/absent/leave totals remain visible.
- Missing/loading data shows a dash and its actual status, not invented zero
  progress. Fractions clamp safely to 0-100%; NaN is unavailable.
- An initial reveal triggers the package's native update animation. Reduced
  motion renders settled values with tickers disabled. Enlarged text moves the
  accessible percentage and label below the arc to avoid fitting text smaller.
- Only Profile summary widgets change. Home, History and Admin data/UI remain
  unchanged. The older ring widget remains available for existing callers/tests.

## Banner Colors And GIFs

- Existing banner options gain **Banner color** alongside image upload and the
  existing inline removal flow. Empty banners offer Upload banner / Banner color
  without a Remove action. Tapping an existing image still opens the gallery.
- `BannerColorSheet` embeds the real Portal `BloomColorPicker`: concentric peel,
  radial swatches, brightness arc, editable hex pill, haptics and native animation.
  Package styling controls fit the wheel to phone widths and existing themes.
- A live draft preview changes locally. Nothing uploads before Save color;
  closing/cancelling preserves the current image. Errors stay inline with retry.
  Pending saves disable controls and retire the picker overlay.
- Color selection is encoded as a tiny opaque 16x16 PNG. The normal
  `saveMedia('banner', bytes)` path stores it in the existing private bucket with
  existing profile ownership, MIME validation, signing and image caching.
- This deliberately avoids a database migration or a second banner schema.
  A color replaces the current image/GIF only when saved. Uploading another
  image/GIF replaces the color through the unchanged upload path.
- Legacy/local mode writes the PNG to application support storage and persists
  its unique path through the existing user-scoped preference. Preview mode
  rejects persistence before encoding or uploading anything.
- GIF handling is unchanged: original animation bytes are preserved; the
  existing 10 MiB GIF-banner / 5 MiB other-media limits remain intact.

## Verification And Boundaries

- Unit/widget cases cover opaque PNG encoding, Storage-format validation,
  backend persistence/reload, failed-save preservation, local restart,
  Preview isolation, real package animation, clamped/missing data, Profile menu
  navigation, cancel/no write, empty-banner uploads, hex preview/save, inline
  retries, both themes, 320dp layouts, 2x text and reduced-motion gauge behavior.
- Golden previews cover the actual expanded overlay, not only its underlying
  Scaffold. Only requested Profile activity/banner-menu baselines were updated.
  New color-sheet closed/open previews were visually inspected in both themes.
- Main Bloom expansion duration and haptics follow reduced motion. Upstream
  0.38.0 also has internal press/hex/slider micro-animations whose durations are
  not all exposed by its public style API; these were not vendored or patched.
- No database/RLS/Edge Function edits or live deployment. Tests use isolated
  files and fake backends, not real user uploads. Phone feel, real gallery
  selection and real signed-in color upload still need owner testing.
- Private entrypoint and SOAP service hashes match their original values.
  Existing `docs/ui-handoff.md` edits and unrelated files stay unstaged.
- The initial source-only prototype was committed as `3916648`. The user then
  requested an APK and final handoff. Delivery details are recorded below.
  Inherited Discord artwork remains a local prototype until replaced or cleared
  for public distribution.
- Final `flutter analyze --no-pub`: no issues. Full regression suite on the
  final source: all **263 tests passed**. Focused package/Profile/banner cases
  and `git diff --check` also passed. No physical-device or real-account upload
  test was performed.

## Wrap-Up Delivery - 2026-11-18

- Branch: `codex/profile-gauge-bloom`; APK source commit: `3916648`.
- Build: ARM64 only, release runtime, public/live Supabase entrypoint
  `lib/main.dart`, using the same existing public client configuration. The
  ignored private SOAP entrypoint/service are not used or modified.
- Build argument: 17, incrementing the previous code-2016 APK without changing
  the application ID or existing test signing key. No uninstall or data reset.
- One APK output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  This replaces the previous artifact at that path; no duplicate APK copies.
- Verified artifact: `com.example.attendance`, version `1.1.0`, Android version
  code `2017`, ARM64 (`arm64-v8a`) only. Size: 22,992,380 bytes (21.93 MiB).
- APK SHA-256:
  `3142044F95D8141CA43FB5A50A8C9DBC544B1A36582DF00E0C4B269C9BE25101`.
- APK Signature Scheme v2 and 16 KiB alignment checks passed. The certificate
  matches the previous test build (SHA-256
  `400660b609acea3238e627da073865006229e231cf9d1f71b6a89e4548851520`).
  It is the Android debug/test certificate, not Play Store signing. The APK
  itself is a release build and is not debuggable.
- No source push, PR update, Supabase deployment or production-data change.
  Existing Gradle/AGP/Kotlin support warnings are left as-is, not bypassed.
- Prior prototype handoffs: `admin-badge-prototype.md`,
  `history-subgroups-prototype.md`, `search-tags-prototype.md`, and
  `banner-inline-delete-prototype.md`. This branch includes all those changes.
- Next phone checks: install as an update, verify Profile gauge animation and
  reduced motion, upload/play a GIF, save a custom hex color, restart and check
  persistence, cancel color selection, test offline save/retry, and confirm
  banner removal and avatar loading still behave normally.
- Broader notifications/recognition/profile-view work remains deferred. Do not
  mix it into this delivery or automatically publish the local badge artwork.

## Rebuild And Install

From the Flutter project directory in PowerShell, with the existing public
Supabase URL and publishable key set in the `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` environment variables:

```powershell
flutter build apk --release --no-pub --split-per-abi --target-platform android-arm64 --build-number 17 -t lib/main.dart `
  --dart-define="SUPABASE_URL=$env:SUPABASE_URL" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"
```

Run `flutter pub get` first on a fresh checkout or after dependency changes.
Use only the publishable client key, never a service-role key. Wait for Flutter
to report that it built the APK before transferring the file to a phone.

The project defaults to `1.1.0+6`. The file found before the rebuild was a signed,
aligned ARM64 APK with version code `2006`, consistent with omitting
`--build-number`. Android cannot install that as a
normal update over the previous `2016` test build. This is a version downgrade,
not evidence that the APK bytes were damaged. Use the same signing key and a
version code at least as high as the installed app; use a higher code for a new
build. Compare `Get-FileHash -Algorithm SHA256` results between copies if you
suspect a transfer issue.

On a USB-debugging-authorized Android device, `adb install -r` reports the
specific installation error and preserves data when the update succeeds:

```powershell
adb install -r "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
```
