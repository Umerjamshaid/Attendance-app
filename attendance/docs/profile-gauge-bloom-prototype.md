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
- No new APK or push was requested for this follow-up. The existing code-2016
  APK predates this change. Next requested update should use a higher build
  argument (17 or greater) and the same signing key. Inherited Discord artwork
  remains a local prototype until replaced or cleared for public distribution.
- Final `flutter analyze --no-pub`: no issues. Full regression suite on the
  final source: all **263 tests passed**. Focused package/Profile/banner cases
  and `git diff --check` also passed. No physical-device or real-account upload
  test was performed.
