# Home And History UI Handoff

Updated: 2026-11-09. Current branch: `codex/centered-swipe-navigation`.
Backend review fixes were already saved in `6bdb462` before this UI task.

## Explicit User Decisions

- Preserve the existing Home and History presentation. Backend integrations must
  not silently replace these summaries or redesign other screens.
- Home keeps **Your attendance**, today's **Not yet / Present** status, the
  colored-dot **Today**, **This month**, and **Day streak** labels and dividers.
- History keeps **Overview**, the monthly progress ring, **Current streak**,
  **Overall rate**, **Days present**, and **Days absent**, followed by its existing
  date-grouped records.
- Restore these in both the public demo and signed-in company path. The legacy
  path uses the same components. Do not hardcode today's status to "Not yet".
- Admin was explicitly out of scope. Leave Admin, the floating navigation,
  Profile/Settings, authentication, uploads, and private integrations unchanged.
  Further visual changes require an explicit user request.

## What Changed

- Home always uses the existing `AttendanceSummaryCard` instead of substituting
  `CheckInSummary` for the public backend.
- History always uses its existing overview instead of the public replacement.
  Its overall rate uses the displayed present/absent totals, so repeated uploads
  on one day do not lower a rate based on distinct recorded days. No provider,
  schedule, absence-inference, server, or payroll rules were added or changed.
- Existing colored dots, dividers, themes, typography and animations remain.
  Labels can wrap at large text sizes; the History ring/facts stack only when
  available width requires it. Reduced motion disables Home metric transitions.
- Added `test/attendance_overview_test.dart` and dedicated light/dark golden
  images. They cover both public modes, changing today's state, duplicate
  submissions, 320dp/large layouts, 2x text and reduced motion.
- Golden tests load a local Inter font fixture with its SIL license under
  `test/support/fonts`. This fixes placeholder-font renders without changing
  production typography, app assets, packages, or the existing golden baselines.

## Resume Safely

- Read this note before changing these screens. Keep reference golden tests
  meaningful; do not regenerate them to approve an unrequested redesign.
- Run `flutter analyze` and `flutter test` after edits.
- The UI-only restoration did not rebuild an APK. The subsequent requested
  build is recorded under **APK Follow-up** below.
- For public-only build verification, use only Git-visible public sources. A
  nested verification copy previously reused stale compiler output. Give the
  copy its own dependency configuration, run `flutter pub get` after any clean
  has finished, and verify that the packaged app contains the intended changes.
  Never clean the original/private build to troubleshoot an isolated copy.
- Private sources remain local and ignored. Do not delete or stage them.
- The previous CodeRabbit docstring recheck was rate-limited, and its local CLI
  could not authenticate. Do not claim that external check passed without a new
  result. These service settings were not changed during the UI restoration.

## Verification At Handoff

- Full Flutter regression suite: 50 tests passed. The seven new overview tests
  also passed after finalizing their golden image backgrounds.
- `flutter analyze --no-pub`: no issues found.
- Inspected all four light/dark reference images with readable Inter typography.
- Private source hashes are unchanged; no Admin, navigation, provider, backend,
  dependency, or production theme files were modified.
- No APK was rebuilt, no live backend settings were changed, and no real-device
  camera/upload verification was performed for this UI-only task.

## APK Follow-up

On 2026-11-06, built the requested public ARM64 release APK from UI source commit
`88c4726`. It replaces the previous artifact at
`.dart_tool/public-verification/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
and is approximately 20 MB. The APK is a local ignored artifact, not a Git file.

The isolated copy contained neither private source file. Its own package
configuration was verified, and only its Dart build caches were cleared to force
fresh compilation while preserving native caches. Packaged UI/session markers
passed; private integration markers were absent. Private source hashes are
unchanged. No application code or live settings changed during this build.

SHA-256: `59BD126D5C64C64B2BF245D25A4622B862067ADA05F4E62AEEB177344C5432EA`.
The existing debug signing and shared application ID remain unchanged. This is
a release-mode test artifact; installing it can replace the private app. Actual
phone camera/upload verification is still separate from build verification.

## Navigation Follow-up (2026-11-09)

The user explicitly approved these navigation changes, superseding the earlier
instruction to leave the dock's placement unchanged:

- Center the existing floating dock. Keep its icons, size, styling, tooltip and
  accessibility behavior. Do not add a separate action button.
- Swipe left/right through the same role-dependent tabs while keeping bottom
  navigation available. Both paths share the selected tab and `PageController`.
- Dock taps retain immediate tab switching; swipe settling uses Flutter's page
  physics with mass 0.5, stiffness 200, and damping 18. Reduced motion uses the
  framework's standard non-bouncy physics and zero-duration dock animations.
- Keep visited screens alive so scroll/form state survives tab changes. Disable
  offscreen tickers and keep Home's existing active-tab signal synchronized.
- Preserve Profile when gaining/losing Admin changes its index. If access to the
  currently selected Admin page is removed, return to Home. Stale dock callbacks
  must not jump beyond the new role's page count.
- This task does not redesign Home, History, Admin or Profile content, or change
  authentication, backend integrations, upload logic, packages or global themes.

Navigation regression tests cover tap/swipe synchronization, rapid taps,
interrupted drags, vertical scrolling, retained page/scroll state, admin refresh,
role changes, RTL, reduced motion and dock centering. Only the two dock golden
baselines change; the Home/History golden baselines must remain unchanged.

Implementation reference: [Flutter PageView API](https://api.flutter.dev/flutter/widgets/PageView-class.html).

Verification: 56 Flutter tests pass; `flutter analyze --no-pub` reports no issues.
The untouched private entrypoint's Dart bundle also compiles. The branch is based
on current `main` after PR #17 was merged, preserving its newer retention fix.
No backend deployment or live settings changes were performed for navigation.

A new public ARM64 release APK from navigation source commit `c16b968` replaces
the earlier artifact at the same local path listed above (approximately 20.1 MB).
Its pager and restored-summary markers are present, private integration markers
are absent, and private source hashes remain unchanged.
SHA-256: `8078CF193748841153FCD568145C0C9BB8F605D49927B4830F505C988997C194`.
Signing/application-ID limitations are unchanged. Actual phone gesture feel was
not verified here; automated touch and state-preservation tests were run.

## Profile Media And Typography (2026-11-10)

- The user approved common profile image formats, smaller compact icons, and a
  typography refresh using the three newly installed design skills. Keep the
  logo, palette, screen layouts, navigation, Home and History summaries intact.
- Avatar/cover selection no longer requests resizing or compression, preserving
  animated GIF/WebP bytes. Public uploads identify JPEG, PNG, GIF, WebP and BMP
  from bytes, assign matching MIME types/extensions, and retain the 2 MB limit.
  Unsupported/oversized selections show useful errors without replacing the
  previous image. The legacy local-only preference flow remains unchanged.
- The profile-media format migration was applied to the configured hosted
  project and read back successfully. Both image buckets remain private and
  limited to 2 MB; attendance-evidence still allows only JPEG/PNG. Existing RLS,
  storage ownership paths and upload cleanup are unchanged.
- Compact camera/remove icons are 16-18dp, inline edit and chevrons 20dp, and
  notification thumb icons 18dp. Existing interactive hit areas stay intact.
- Profile/Settings/Privacy use bundled DM Sans with natural line spacing and
  zero letter spacing. Shared type helpers retain their original Inter styles
  outside that scoped theme, preserving Home/History/Admin typography.
- DM Sans has no tabular numerals. Attendance counters deliberately keep Inter
  with tabular figures; do not replace them with DM Sans. The font audits pass
  English base coverage/licensing and the data font's tabular-number gate.
  Both fonts have a heuristic I/l similarity warning. DM Sans lacks the optional
  English auxiliary character U+02BB; system fallback remains available. WOFF2
  size estimation was skipped because it is not an app-format requirement.
- The unmodified DM Sans asset and OFL license are under assets/fonts. Font
  source/provenance is recorded there. No new launcher icon was requested or
  generated; icon-skill guidance was used for small-size clarity only.
- Added regression tests for signatures, upload MIME/bytes/path ownership,
  animated frames, cancellation, invalid input, preview restrictions, legacy
  local media, compact icon hit areas, scoped fonts and tabular counter widths.
  Profile and Settings have updated light/dark reference images; Home/History
  golden baselines must remain unchanged.
- No real-account photo was uploaded, no APK was rebuilt, and no Git push was
  performed for this follow-up. Owner-only source hashes remain unchanged.
- Final verification: all 68 Flutter tests pass, analyzer reports no issues,
  isolated migration/RLS tests pass, and the hosted bucket metadata is verified.

## Profile Release APK And Push (2026-11-10)

The user subsequently approved committing, pushing, and rebuilding. Public source
commit `919f66d` was pushed to `codex/centered-swipe-navigation` and PR #18 was
updated. The PR remains open; `main` was not merged.

The updated public ARM64 release APK replaces the earlier artifact at the same
isolated-build path listed above. Size: 21,186,927 bytes (approximately 20.2 MB).
SHA-256: `9029DD7A740F7340472D9D5FB2BDFEB0C44449D236982BC2C7490E85626A7E01`.

The public-only copy exactly matches the committed Dart sources, assets and
dependency files. Packaged image-format/navigation markers are present, and
private-service markers are absent. The bundled DM Sans font matches the source
asset byte-for-byte. Both owner-only source hashes remain unchanged.

The build succeeds with existing Gradle/AGP/Kotlin future-compatibility warnings;
this task does not upgrade that toolchain. Existing debug signing and the shared
application ID remain unchanged, so installing this public APK can replace the
private app. No physical-device upload test or GitHub APK release was performed.

## Admin Check-in Logs Sheet (2026-11-10)

The user explicitly requested a modal bottom sheet instead of the separate
employee Check-in Logs page. Do not redesign or restructure the Admin dashboard.

- Only the public employee log action in EmployeeCard changes. The legacy
  employee attendance/totals sheet, filters, dashboard layout, attendance window,
  and evidence screen remain unchanged.
- employee_check_ins_sheet.dart owns this specific modal and loads the same
  backend history with the same employee ID. No API, authorization, schema,
  evidence retention, or private-service behavior changes.
- The modal retains Material's barrier/focus/drag behavior and uses a
  DraggableScrollableSheet with its supplied scroll controller. Logs are lazy
  rows grouped by date. Native scrolling and resizing share one gesture flow;
  the header and close action stay reachable while scrolling.
- Entrance/exit use critically damped spring simulations via the sheet route.
  Material still handles drag/fling dismissal; reduced motion has zero-duration
  transitions. The supplied non-scrolling spring-route example was deliberately
  not pasted over a growing list.
- Use existing DM Sans for sheet text, Inter tabular figures for times, and
  semantic Tabler icons sized 18-20dp. Refresh/close have explicit 48dp hit areas.
  The sheet is capped at 560dp on wide screens. Large text can wrap the title.
- Loading, refresh, retry and empty states remain inside the modal. A log opens
  the existing evidence page; Back returns to the same sheet without re-fetching.
  Date headings and evidence buttons have separate accessible semantics.
- The obsolete EmployeeCheckInsScreen wrapper was removed from
  attendance_evidence_screen.dart; AttendanceEvidenceScreen itself is unchanged.
- Ten focused tests cover modal vs page routing, both themes, 320dp/2x text,
  scrolling/resize, all dismissal paths, pending requests, refresh/retry/empty
  states, evidence return navigation, semantics, RTL/reduced motion, and legacy
  totals. Only two new sheet reference images were added; do not regenerate
  existing Home/History/navigation/profile references for this change.
- This follow-up does not build another APK or push/merge Git changes. Actual
  phone gesture feel remains unverified. All 78 Flutter tests pass and analyzer
  reports no issues. Existing reference images and private source hashes are
  unchanged; the two new sheet images were visually inspected.

Implementation references:
[Flutter DraggableScrollableSheet](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html)
and [TransitionRoute.createSimulation](https://api.flutter.dev/flutter/widgets/TransitionRoute/createSimulation.html).

## Petrol And Graphite Palette (2026-11-10)

The user approved applying the researched Petrol + Graphite palette. This is a
color-only update to the shared theme, not permission to redesign any screen.
Existing typography, geometry, Home summaries, History overview, navigation,
Admin structure, and the new Check-in Logs modal are preserved.

- app_theme.dart owns the palette. Light mode uses primary #167D8D, selected
  container #DFF1F3, page background #F7F9FA, white surfaces, body #202326 and
  secondary text #5D6368. Dark mode uses primary #67D5E5 with #102B31 ink,
  selected container #16343A, page #141719, surface #1F2327, body #F1F3F5 and
  secondary text #ADB5BD. Container and border roles use neutral graphite steps.
- Page Scaffolds and app bars in Home, History, Admin, Profile, Privacy,
  Notifications, Login and Splash now inherit the theme background. The shared
  Settings layout and navigation footer use that same background. Sheets and
  dialogs retain their surface roles. No layout or interaction changes.
- The dock's selected fill uses primaryContainer. Avatar initials use the
  primaryContainer/onPrimaryContainer pair across Home, Profile and employee
  cards/sheets. The existing fallback profile banner uses deep petrol rather
  than navy. Old public color constant names remain available for compatibility.
- Small text actions use the darker petrol ink in light mode, rather than the
  main fill color on tinted surfaces. Light card fill is #F0F3F5 so the unchanged
  green attendance text still meets 4.5:1 on the base card. The original green,
  red and amber attendance colors are unchanged in both modes.
- app_theme_test.dart adds six tests covering exact palette roles, text contrast
  pairs and unchanged attendance colors with base-surface contrast. The login
  widget test now checks its rendered Material background when toggling themes,
  instead of requiring an explicit Scaffold color override.
- User approval supersedes earlier color-baseline restrictions for this task:
  14 light/dark reference images cover Home summary, History, dock, Login,
  Profile, Settings and Check-in Logs. Only palette-driven appearance changed;
  existing layout, scaling, state and navigation assertions remain in force.
- All 84 Flutter tests pass and analyzer reports no issues. Light/dark renders
  were visually inspected. The private entrypoint and service retain their
  previous SHA-256 hashes. No API,
  provider, storage, dependency, authentication or backend settings changed.
- This update remains local on the existing branch. No commit, push or APK
  rebuild was requested. Actual-device appearance/upload testing was not done.

### Requested APK Follow-up

The user then requested an APK. Built one public ARM64 release from the current
working sources, including the palette and Check-in Logs sheet. It replaces the
previous APK at the isolated-build path above: 21,252,463 bytes, SHA-256
`128D017343BACA88ACEC948331F1C0168727EA8297EF79197414CCA8A25DE4C7`.
The source copy excludes both private Dart files. Its package root and current
theme hash were verified; the packaged new-sheet marker and bundled font are
present, and private integration markers are absent. Owner-only hashes remain
unchanged. No commit or push was performed. Existing signing/application-ID
limitations still apply, and physical-device testing remains outstanding.

## Evidence Addresses And Login (2026-11-11)

The user explicitly approved adding readable evidence locations and redesigning
Login, with the supplied parent-folder block-analysis.md as reference. Details,
package comparison, modified-file map and historical-address storage decision
are recorded in [evidence-location-and-login.md](evidence-location-and-login.md).

- Address lookup is isolated from check-in verification/submission and resolves
  only the evidence endpoint's saved coordinates. Existing evidence fields and
  strings are retained. No backend/schema/private-service changes were made.
- Native geocoding uses a bounded, account-scoped memory cache and serialized
  requests with UI timeouts and fallback/retry. Addresses are not persisted or
  promoted to verified historical evidence; a server snapshot is a future task.
- Shared tokens reuse bundled DM Sans, the approved palette and Tabler icons.
  Login has consistent fields, keyboard/autofill, password visibility and short
  reduced-motion-aware transitions. Authentication/validation behavior remains.
- Spring press feedback is local to controls, with unchanged layout/hit areas.
  The existing page spring values and synchronized navigation are preserved.
- Fixed the existing evidence Retry callback returning a Future from setState.
- All 110 tests pass. Only the two existing Login reference images were updated;
  four new company-Login/evidence references were added. All 12 non-Login
  reference images still match the prior palette build. Private hashes match.
- Final flutter analyze --no-pub reports no issues.
- Changes remain local. No live records or backend settings were changed, and
  no real-device upload/geocoding or iOS build has been verified.
- Public ARM64 release compilation succeeds with the compatible geocoding
  adapter. The existing isolated APK was replaced (approximately 20.4 MB).
  New address/Login markers and the bundled font are packaged; private and
  fixture markers are absent. The exact checksum and signing limitations are
  recorded in the implementation notes. No commit or push was performed.

## Review Follow-up (2026-11-11)

The initial UI/location work was published to PR #18 as c4e7d65. The user then
provided four low-risk review findings; all four were verified against the code.

- EditProfileSheet now wraps its content with ProfileUi.themeOf and an inner
  Builder. Helper text, fields, errors and buttons inherit the same profile font;
  save/validation/navigation behavior is unchanged.
- Profile footer labels use opaque onSurfaceVariant. This fixes the contrast
  loss caused by their own 70% alpha without changing the shared palette. Tests
  verify both footer labels exceed 4.5:1 in light and dark themes.
- Invalid evidence coordinates have a specific message. Original latitude and
  longitude strings remain visible, and invalid values do not call a geocoder.
- Address lookup uses the device's primary preferred locale, independently of
  the app's English-only UI fallback. A WidgetsBindingObserver reloads when that
  primary locale changes and is removed on disposal. English is only the
  fallback when the platform supplies no preferred locale.
- Existing locale-keyed caching and in-flight deduplication are retained. Tests
  cover Urdu/French preferences, unchanged primary preferences, cached locale
  restoration, stale in-flight results and listener disposal.
- All 119 Flutter tests pass, including nine new regression cases. No golden
  images were regenerated. Private hashes and unrelated notes are unchanged.
- Final flutter analyze --no-pub reports no issues.
- These follow-up changes remain local. No APK rebuild, commit/push, live
  backend change, real-device test or CodeRabbit CLI review was performed.

## Review Publication And Rebuilt APK (2026-11-11)

The user subsequently requested completing publication, APK rebuild and the
optional CLI review. Review-fix source 4adbc47 was pushed to the existing PR #18;
main was not merged. All four original review threads are resolved, with a
consumer-side contrast explanation recorded for the footer finding.

The expired CodeRabbit CLI session was renewed through user-completed browser
authentication. Review ran in a shallow public-only checkout, comparing 4adbc47
to c4e7d65. It completed successfully with zero findings across the six changed
public files. No ignored private source, API notes or unrelated local notes were
available in that checkout. No additional review credits were explicitly enabled.
The GitHub bot's automatic check was separately neutral/skipped because of a
service rate limit; no check configuration was changed or bypassed.

The existing public ARM64 release APK was rebuilt from the pushed fixes and
replaced at the same isolated-build path. Size: 21,400,859 bytes. SHA-256:
`08096EFBF755A6284953A6A44F7E09846A13EB5F98C9253CB50A0637D2F9FD6E`.
Public sources matched the working files. The packaged invalid-coordinate fix,
other current UI markers and bundled font are present; private integration and
fixture-address markers are absent. Both private source hashes are unchanged.

The source retains the verified 119 passing tests and clean analyzer result.
Existing test signing, shared application ID and Gradle/AGP/Kotlin warnings
remain. Physical-device and iOS testing are still outstanding. The APK is local,
ignored and not uploaded as a GitHub release asset.
