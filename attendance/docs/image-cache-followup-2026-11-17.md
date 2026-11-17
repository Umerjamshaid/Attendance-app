# Image Cache Follow-Up - 2026-11-17

## Scope And Decisions

- Stop repeated image loading in the office switcher and profile without changing
  the UI, attendance logic, authentication, or access rules.
- The owner clarified that this task is about image reuse, not deactivation
  policy. Preserve the existing avatar-sharing policy, including its retained
  inactive-membership behavior. The related PR #22 review threads explain this
  deferred product decision. No migration or live Supabase deployment is needed.
- Work stays on `fix/coderabbit-issues`. PRs #21 and #22 have already merged;
  publish the cache changes as a new follow-up PR targeting `main`.

## Fixes

- `employee_check_ins_sheet.dart`: omitted avatar IDs mean refresh failure and
  preserve the displayed photo. Only explicit null means confirmed removal.
- `profile_cache_cleanup.dart`: failed namespace purges have a one-minute retry
  interval. A newly remembered namespace resets the interval. Coalescing,
  persistent pending namespaces, and non-blocking sign-out remain intact.
- `profile_image_cache.dart` and `signed_profile_url.dart`: private office logos
  now use stable object-version cache keys and the existing expired-URL renewal
  path, just like profile avatars and banners. Viewer and office keys remain
  separate; sign-out still retires and purges the viewer's cache.
- `company_backend.dart` and `supabase_company_backend.dart`: office logos sign
  in batches of up to 100 instead of one sequential request per office. Uncached
  expired logos can renew through the authenticated account backend; Storage
  independently enforces office membership. Foreign origins/paths are rejected.
- `office_selector_header.dart`: all `OfficeAvatar` instances use the shared
  private image cache, including the header, sheet, and morphing avatar.
- `office_model.dart` and `office_provider.dart`: a failed optional signing
  refresh preserves a previous URL only if the authorized office and logo path
  are unchanged. Fresh names and roles still replace old values. Actual removal
  or a new logo path does not retain the old logo.
- `profile_header.dart`: avatar transitions use stable image identities rather
  than signed tokens, with gapless image replacement. Existing banner identity,
  error-revision, retry, GIF-byte preservation, and cache behavior remain intact.

## Regression Coverage

- Logs refresh: missing UUID preserves a photo; explicit null clears it.
- Cleanup: repeated failures are throttled and a new retirement retries promptly.
- Profile and office-logo cache: rotating tokens reuses original GIF bytes and
  decoded keys; sign-out removes the actual file as well as denying old access.
- Office backend: batched signing, renewal after office selection, foreign-origin
  rejection, and server access denial.
- Office provider: signing failure preserves the unchanged logo, but not stale
  names/roles or removed/replaced logo paths.
- Profile UI: token rotation preserves avatar/banner elements; outgoing-banner
  errors cannot change the current image's failure state. The widget fixture
  mocks preferences and waits for both cached images to finish decoding.

## External Reference Clone

- Requested repository cloned to `D:\work\APP flutter\discord-badges`, beside
  `buzz-mobile`, not inside Attendance.
- Origin: `https://github.com/mezotv/discord-badges.git`; shallow checkout at
  `7175b74`. No repository scripts were executed or badge assets added to the app.

## Safety And Remaining Checks

- Ignored private entrypoint and SOAP service remain untouched; no private
  imports, keys, production-data changes, uninstall, or app-data reset.
- User edits in `docs/ui-handoff.md`, attachments, old mockups, ZIPs and unrelated
  untracked files are preserved and excluded from this commit.
- Physical-phone repeated-navigation behavior, large animated GIF playback, and
  haptics still need device testing. First-time downloads and real image changes
  still need loading; caching does not promise permanent storage after OS eviction.
- Final validation: `flutter test --no-pub --concurrency 2` passed all 221 tests;
  `flutter analyze --no-pub` found no issues. Disposable PGlite migration/RLS
  tests passed; there are no new database migrations in this change.
- The optional CodeRabbit CLI review was not rerun. The submitted findings were
  checked against current code and covered by the focused regression tests.

## Delivery

- Source commit: `1dd2bbe`, pushed to `fix/coderabbit-issues`.
- Follow-up PR: https://github.com/Umerjamshaid/Attendance-app/pull/23, targeting
  `main`; no automatic merge. The submitted Logs/avatar, nullable-test, and
  cleanup-backoff threads on merged PR #22 received fix/test replies and were
  resolved. The two deactivation-policy threads received deferral explanations.
- Public/live ARM64 release APK rebuilt at
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`: 22,333,724 bytes
  (about 21.3 MiB), version name `1.1.0`, build argument `15`, APK code `2015`,
  package `com.example.attendance`. This replaces the prior APK at the same path.
- APK SHA-256:
  `1493C5F52BACBD4535D9D8B0210CD435EE46386DAD9948823BEE918E20AABCA1`.
- APK v2 signature and 16 KiB alignment checks passed. The signing certificate
  SHA-256 remains
  `400660b609acea3238e627da073865006229e231cf9d1f71b6a89e4548851520`,
  matching the previous test APK. Runtime is release, but signing still uses
  the existing Android debug/test certificate, not a Play Store release setup.
- Existing Gradle/AGP/Kotlin future-support warnings remain; no dependency
  validation was bypassed or unrelated Android-toolchain upgrade performed.
- The owner also asked how to stop Cubic automatic reviews. Explained its
  repository-level AI reviews setting; no reviewer settings/config were changed.
