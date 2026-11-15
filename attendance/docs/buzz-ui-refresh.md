# Buzz UI Refresh Handoff

Updated: 2026-11-15. Branch: `codex/buzz-ui-refresh`.
Base: `755f60d`, the existing multi-office rollout checkpoint.

## Read This First

This is the current UI handoff. Dated checkpoints below are historical; later
sections supersede earlier APK, palette, test-count and deployment statements.
Do not interpret an old "not pushed" or "no live changes" line as current state.

- Keep the softer gray/teal palette, bundled Inter, Tabler icons and selective
  animated Lucide dock icons. Do not restore a pure-black Buzz palette or
  replace the entire icon family.
- Preserve Home's Today / This month / Day streak and History's full Overview.
  Keep centered navigation, synchronized swipes, and the existing office-switcher
  selection/hide/restore behavior. Do not redesign Admin beyond requested work.
- Implemented follow-ups include capsule toasts, inline validation/shakes,
  lifecycle/read coalescing, the office-role sheet, Profile progress ring,
  Admin roster PFPs, and the PFP in the Check-in Logs bottom-sheet heading.
- Profile avatars/banners now use viewer-scoped disk caching and retain animated
  image bytes. The shared password-recovery flag fixes the post-save spinner;
  account request deadlines and inline retries remain in place.
- Profile media now permits 5 MB (5,242,880 bytes) in the app and live Storage.
  Attendance evidence and office logos remain 2 MB. Both approved avatar-read
  and profile-size migrations are deployed; do not replay them manually.
- Latest local public/live ARM64 APK: version 1.1.0, code 2013, approximately
  21.2 MB. Its path, checksum, test signing and verification are recorded below.
  It includes caching, Logs PFPs, recovery fixes and the 5 MB allowance.
- The user will supply refreshed mockups and a demo video. Do not invent those
  assets or present the old gallery as the current UI. Both READMEs now describe
  the functional public app and distinguish demo from invite-only company access.
- Shorebird was discussed only: it is not installed or configured. Notifications,
  badges and wider onboarding/collaboration additions remain deferred pending
  the user's requirements. No full security-audit work or subagents should resume.
- Never stage the ignored private entrypoint, SOAP implementation, API notes,
  local backups, APK/build output, test failure images or attachment directories.
  Unrelated pending changes in the historical ui-handoff and local design/prompt
  notes remain untouched and must not be swept into this publication.
- Publication target: `codex/buzz-ui-refresh`, based on the still-open
  `codex/multi-office-switcher` PR #19. Publish a separate stacked UI PR; do not
  merge main, rewrite history, or replace #19 as part of this request.
- Current validation and publication result are recorded at the end of this
  document. Physical-phone animation/haptics, real gallery/recovery acceptance
  and iOS checks remain outstanding; no production-store signing was configured.

## Approved Scope

- Redesign existing screens only. New collaboration features and onboarding are
  deferred; retain Provider, CompanyBackend, authentication, and office isolation.
- Keep Tabler icons throughout the app. Use `flutter_lucide_animated` selectively,
  not as a wholesale replacement; do not add a static Lucide companion package.
- Adapt Buzz's actual in-app action feedback, not operating-system notifications.
- Preserve Home's Today / This month / Day streak summary and History's Overview,
  progress ring, current streak, overall rate, and present/absent totals.
- Preserve the centered dock, synchronized swipes, and the office switcher's
  keep-open selection, haptics, local hide/restore, and administrative behavior.
- Do not restart the previously stopped full security audit or spawn subagents.

## Implementation

- `lib/config/buzz_color_scheme.dart`: Buzz's semantic color structure, now
  adapted to Attendance's softer gray surfaces and teal accents following the
  2026-11-15 palette feedback; no rebranding or backend changes.
- `app_theme.dart` and `ui_tokens.dart`: bundled Inter scale, flat controls,
  consistent dimensions, 24dp action icons, and sheet/dialog styling. Existing
  public constant names remain compatible. Light success/warning shades are
  slightly darker than Buzz's to maintain AA contrast on attendance surfaces.
- `utility_surface_theme.dart` and `settings_layout.dart`: idempotent utility
  surfaces for Settings, with existing rows/actions and grouped hierarchy intact.
- Existing UI widgets use `AppTypography.inter` instead of runtime font fetching;
  ProfileUi shares the same bundled font. Tabular numeric features are retained.
  Existing DM Sans assets/dependency declarations are not deleted as cleanup.
- `animated_app_icon.dart` and `bottom_nav.dart`: four selected-tab animations,
  24dp / 2.5 stroke, manual triggers, no nested tap handler, no looping. Reduced
  motion and offscreen ticker suppression stop/reset playback.
- `app_toast.dart` and `app.dart`: top overlay feedback with Buzz's capsule reveal,
  slide motion, semantic haptics, and one-notice replacement. Root navigation is
  not recreated by an office change. Captured feedback clients reject stale
  office/account results. Existing UI callers retain their messages/actions and
  timeouts; confirmation dialogs remain dialogs. Long errors scroll and enlarged
  action layouts stack. Accessible action notices do not expire automatically.
- `pubspec.yaml` / lock: `flutter_lucide_animated: ^0.0.4` plus its transitive
  `path_parsing`; existing Inter asset registered under the global `Inter` family
  while retaining `Office Inter` for the switcher. No broad package upgrade.
- Attribution and bundled Apache/Inter license registration updated; see
  `docs/third-party-animations.md` for upstream paths and deliberate adaptations.

## References

- Separate Buzz checkout: `../buzz-mobile/mobile` relative to the app's parent
  workspace directory, not a dependency vendored inside Attendance.
- Updated Buzz revision: `59ae028a360242d43ffbfdafca8a76eda00484d9`.
- Read the existing `docs/ui-handoff.md` as historical preservation guidance.
  This explicitly requested refresh supersedes its old font/color baseline, not
  its attendance summary or behavior requirements. Its unrelated local changes
  were preserved rather than staged or overwritten.

## Validation And Limits

- Added focused animated-icon, toast lifecycle/action/large-text, utility-theme,
  and light/dark Privacy tests. Existing UI golden baselines were intentionally
  refreshed for the approved shared theme and bundled font, not for a behavioral
  redesign. Login validation, provider calls, preview isolation, GIF/JPEG/PNG
  handling, office scopes, and check-in evidence tests remain in the suite.
- The disk interruption was followed by a verified local source/Git ZIP backup
  outside the repository before further edits. Git object integrity passed;
  dangling historical objects were not deleted. Both ignored private source
  hashes still match their pre-task values.
- No live database, RLS, Edge Function, authentication, or notification settings
  changed. No new backend endpoint or real attendance submission was exercised.
- The standard Flutter toast is used on iOS too; native Dynamic Island rendering
  was not copied without its platform implementation. Physical-phone haptic and
  animation feel, iOS rendering, and real camera/GPS uploads still need testing.
- Final analyzer/test/APK results are recorded below. Do not
  infer a push, deployment, production signing, or physical-device test from a
  successful local build.

## Final Checkpoint

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub`: all 154 tests passed without updating goldens in the
  final run. The eight toast tests cover replacement/timeouts, persistent
  accessible actions, stale office clients, modal/navigation preservation,
  haptic requests, long-error scrolling, and light/dark/2x-text layouts.
- Reviewed representative light/dark images for Login, Settings, Profile,
  Privacy, attendance summaries, History, navigation, Check-in Logs, evidence,
  office switching, and toasts. This is widget-level visual validation, not a
  physical phone or iOS rendering claim.
- Built `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`: public/live
  Supabase configuration, release mode, ARM64 only, approximately 20.9 MB,
  version name 1.1.0 / version code 2010 (`--build-number 10`).
- APK SHA-256:
  `2527B630DFAEAC0DD7C897B6DB52147ACA87A86384B2EAC798D3991508926F9A`.
- APK v2 signature and 16 KiB alignment verified. Existing debug/test signing
  identity is deliberately retained for update compatibility; this is not a
  production-store signing rollout. No app was installed, uninstalled, or reset.
- Bundled Inter and the switcher's original font alias verified in the package.
  Known private SOAP operation/hostname markers are absent from the public
  application library; public Dart sources have no private service imports.
- Gradle 8.14.0, AGP 8.11.1, and Kotlin 2.2.20 produce future-support warnings
  with the installed Flutter SDK. They were not upgraded in this UI-only task.
- No provider/service, Supabase migration/function, or Android configuration
  diff; ignored private source hashes unchanged. No source commit, push, PR
  update, or live deployment was performed for this refresh.

## Navigation Tap Replay Follow-up (2026-11-15)

- User clarified that tapping a dock icon should animate it, including tapping
  the already-active tab. Previously, only a selection change played the icon.
- `bottom_nav.dart` now increments a local activation counter from the shared
  pointer, keyboard, and accessibility action handler. Parent navigation still
  receives exactly one callback per activation.
- `animated_app_icon.dart` replays when the selected icon's counter changes;
  selection changes from swipes still animate. Rapid taps restart the same
  360ms one-shot animation, not a loop. Reduced motion/offscreen suppression,
  24dp dimensions, 2.5 stroke, and static golden appearance are unchanged.
- Added dock regressions for all destinations, active-tab replays, rapid repeats,
  reduced motion, keyboard activation, and the node's own semantics action path.
  The full suite passes all 157 tests without regenerating goldens. Flutter
  analysis and the finalized navigation test's analysis report no issues.
- This follow-up changes only the two icon/navigation widgets, their navigation
  test, and this note. Notification delivery and office role editing remain
  future tasks; no providers, private files, backend, or native settings changed.
- No APK rebuild, commit, or push for this follow-up. The version-code-2010 APK
  recorded above predates active-tab tap replay; do not present it as containing
  this change.

## Requested APK And Reference Update (2026-11-15)

- Subsequently built the requested public ARM64 release APK with tap replay:
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, approximately 20.9 MB,
  version name 1.1.0 / version code 2011 (`--build-number 11`). This replaces the
  local artifact at the same path; the 2010 details above are historical.
- SHA-256:
  `8E9B0B37A086D24D2282D87D5BE0B1C09C47D37CCA6D2A697D2BFD71B45C9F28`.
- APK v2 signature and 16 KiB alignment passed. The existing signing certificate
  is unchanged, and the private SOAP operation/hostname marker scan passed.
  Release runtime still uses the existing debug/test certificate for in-place
  update compatibility, not a newly configured production-store identity.
- Refreshed the separate clean Buzz reference checkout again, fast-forwarding
  `59ae028` to `69742376a9b1b15da62295f54a053913540722c1`: 27 new commits and
  58 changed files. It is synchronized with `origin/main` as of this update.
  The shared theme, toast, and community-switcher source files already adapted
  for Attendance did not change in that range. Attribution remains pinned to
  the implementation reference; new Buzz features were not silently ported.
- No phone installation, source commit, push, live backend deployment, or
  notification/role-editing implementation was performed in this build task.

## Softer Palette And Selected Buzz Follow-ups (2026-11-15)

- User approved keeping the Buzz layouts, typography and motion, but requested
  softer gray instead of the black-heavy palette. Dark pages now use charcoal
  (`#242629`) with layered gray controls; light pages use a subtle gray-white
  background (`#F7F9FA`). Teal is restored for primary actions and selection.
  Attendance success/warning/error colors and the 4.5:1 contrast checks remain.
- `app_shell.dart` ignores brief `inactive` interruptions and refreshes after
  genuine background/resume transitions. Overlapping resume refreshes share one
  pending operation. Existing tab/swipe behavior is unchanged.
- Profile, attendance history and admin providers share pending reads instead
  of issuing duplicate requests. Generation/disposal checks reject stale
  results. A saved image/banner or accepted check-in retires an older load so
  that response cannot replace the new data; failed reads retain loaded data
  and allow retry. No persistent cache, backend endpoint or package was added.
- `office_role_sheet.dart` replaces the existing role dropdown interaction with
  a theme-aware modal sheet. Draft selection does not save automatically; Save
  changes stays disabled until edited, the existing confirmation is retained,
  and rejected changes leave the sheet open for retry. The existing authorized
  `setEmployeeRole` backend/RPC is unchanged, including owner and last-admin
  protections. This does not introduce new role permissions or restructure Admin.
- Role-sheet regression tests also caught an existing debug-mode error from a
  `setState` callback returning its assigned Future. Save/retry callbacks now
  return void. Tests cover cancellation, rejection/retry and dismissal mid-save.
- Added nine provider refresh/race tests, two lifecycle tests and five role-sheet
  tests. Approved palette goldens were refreshed, then all 173 tests passed in
  a final `flutter test --no-pub` run without updating goldens. Narrow screens,
  2x text, reduced motion, preview isolation, office switching, media formats,
  authentication, evidence and navigation remain covered.
- `flutter analyze --no-pub`: no issues found. `git diff --check` also passed;
  existing Windows line-ending notices are not whitespace errors.
- Reviewed updated light/dark Login, Settings, History and role-sheet renders.
  Both ignored private source hashes remain unchanged. Notifications are
  explicitly deferred until the user supplies their requirements. No database,
  RLS, Edge Function, native setting or live attendance data changed.
- No commit, push, deployment or APK rebuild for this follow-up. The version-code
  2011 APK above predates this palette/reliability/role-sheet work. A future ARM64
  build should use build number 12 (version code 2012) or higher.

## Admin Profile Photos And Profile Progress (2026-11-15)

- The user clarified that employee profile photos belong on the **Admin
  dashboard employee cards**, replacing initials when available. Do not turn
  personal History into an all-employee feed. The initial Check-in Logs header
  prototype was removed; the existing history/log layouts and actions remain.
- `CompanyBackend.employeeAvatars` returns current profile photos by account
  UUID. Supabase reads only `user_id,avatar_path`, in batches of at most 100,
  validates avatar ownership, and signs each batch for 60 seconds. Missing files
  are per-item failures, not failures of the whole roster. Existing dependencies
  and the SDK's typed `createSignedUrlsResult` API are reused.
- AdminProvider hydrates these photos independently after names/status data.
  Generation/disposal guards prevent stale photos from an earlier refresh or
  office overwriting current data. Photo failures leave the roster usable;
  dashboard refresh retries. No persistent signed-URL cache or per-row lookup.
- EmployeeCard keeps its 40dp circular avatar, existing typography, spacing,
  attendance detail action and status. Photos fade in once, with reduced motion
  respected. Initials remain behind slow, missing or failed photos as a fallback.
  This is the employee's current PFP, not an attendance-day snapshot. Legacy and
  Preview integrations without profile-photo URLs keep their existing fallback.
- Profile's public Check-in activity now includes a monthly progress ring,
  distinct days this month, raw check-in count and day streak. Percentages still
  use the existing monthly-rate calculation; repeated uploads do not invent
  extra days. Loading/errors show unavailable progress, not misleading zeros.
  The legacy presents/absents/leaves overview gains its existing attendance-rate
  percentage as a ring without changing its denominator. No goals, rewards,
  notifications, payroll rules or absence inference were added.
- New `attendance_progress_ring.dart` uses a bounded determinate indicator,
  tabular Inter numbers, one short animation, accessible percentage semantics,
  theme colors, and reduced-motion handling. Narrow/2x-text layouts stack.

### Approved Storage Rollout

- Owner explicitly approved applying the tested avatar read rule to live
  Supabase. Applied only `20261115130918_office_admin_avatars.sql` through CLI
  migration history with an explicit project target and `--skip-vault`. Dry-run
  listed that migration only; no roles, seed data or Vault updates were included.
- The additive SELECT policy permits active admins of the selected office to
  read only a member's currently referenced avatar. It does not expose banners,
  unreferenced avatars, other offices, attendance evidence, or write access.
  Existing own-media access is retained, and both buckets remain private.
- Readback confirms the exact policy and recorded migration. Counts before/after
  match: 2 organizations, 6 memberships, 5 profiles, 11 check-ins, 11 evidence rows
  and 19 Storage objects. No media bytes or application records were changed.
- The isolated actual-migration PostgreSQL/RLS suite verifies office separation,
  employee denial, demotion/revocation, banners/orphan denial and own-avatar
  preservation alongside all prior multi-office tests. Security advisors at
  ERROR level found no errors before rollout; this is not a full security audit
  and does not resolve previously documented warnings.
- A live read-only SQL-role probe was rejected by the CLI's statement whitelist
  because it contained SET; it was not retried with write privileges. Do not
  claim a live authenticated Storage download or physical-phone check from the
  policy readback. Mocked real-SDK request tests and isolated RLS tests cover it.
- Rollback, if required, is a forward migration dropping only
  `office_admin_avatar_read` on `storage.objects`. Issued signed URLs can remain
  usable until their 60-second expiry; no bucket or data deletion is necessary.

### Delivery

- Source and migration remain local on `codex/buzz-ui-refresh`; do not confuse
  the approved live rule rollout with a Git push or APK rebuild. Preserve and
  publish the new migration with the matching app source on the next approved
  push. Both ignored private source hashes still match the earlier checkpoint.
- Added focused tests for batched avatar requests, partial failures, stale office
  responses, Admin card geometry/fallback, refresh/retry/disposal, Profile rates,
  duplicate check-ins, unavailable data, semantics, narrow screens and reduced
  motion. Two new Profile activity goldens document the intended appearance.
- Final `flutter test --no-pub`: all 184 tests passed without updating goldens.
  The isolated migration/RLS suite also passed with the actual new policy.
- Final `flutter analyze --no-pub`: no issues found. Avatar loading uses the
  existing SDK and no dependency or private-entrypoint changes were required.
- No APK rebuild or physical-device/iOS verification for this follow-up.

References: [Storage access control](https://supabase.com/docs/guides/storage/security/access-control),
[Flutter signed URLs](https://supabase.com/docs/reference/dart/storage-from-createsignedurl).

## Inline Field Errors And Buzz Shake (2026-11-15)

- User requested error text beside inputs and Buzz's short shake rather than
  toast-only form failures. The screenshot is a validation reference, not a
  request to restore Buzz's black palette or redesign form layouts.
- Read actual upstream `community_link_form.dart` and `pairing_error_shake.dart`
  at `69742376a9b1b15da62295f54a053913540722c1`. Shared `widgets/error_shake.dart`
  retains the 280ms timing, horizontal 0/6/-6/4/0 stops, 80/80/60/60 leg weights
  and Cubic(0.22,1,0.36,1). A disposable native controller replaces hooks; the
  unchanged child is reused while translating. Reduced motion/offscreen content
  stops the motion immediately. Revisions allow the same invalid submission to
  shake again without looping or restarting on unrelated rebuilds.
- Login places missing/invalid work-email and missing-password messages on the
  corresponding inputs and focuses the first invalid field. Existing acceptance
  checks and credential payloads are unchanged. General company sign-in failures
  persist below the credentials; legacy employee-ID failures stay under that
  field. Editing clears stale errors. Success/recovery confirmation behavior and
  demo navigation are retained; no validation-only toast is emitted.
- AccountEditScreen, EditProfileSheet, ProfileDetailsScreen, employee invitations
  and the office-name dialog use the same feedback. Existing native validators,
  dirty/save guards and backend calls remain. Invalid tag drafts stay editable
  rather than being converted into chips; the existing 12-tag/40-character save
  limits are unchanged. General save errors remain visible inside their forms.
- The shared input theme resolves labels to the existing error color only in
  WidgetState.error and permits multiline errors. Inline messages have room to
  wrap at 320dp/2x text; normal colors, typography, fields and navigation are not
  redesigned. Input values, selection and keyboard focus survive feedback.
- The connected employee-list reload callback now returns void from setState
  instead of its assigned Future, avoiding the existing debug assertion after
  an invitation succeeds. No employee authorization or invitation payload changed.
- Toasts remain for non-field actions, upload/permission failures and successful
  confirmations. This is not a global toast removal or a notification-system task.
- Added three shared-motion and six form interaction/reference tests, including
  repeat attempts, focus/selection, reduced motion, disposal, field-specific
  errors, unchanged invitation payloads/retries, invalid tag drafts, office-write
  prevention, light/dark references and narrow/keyboard/large-text layouts.
  Existing Login tests now assert separate field messages and no failure SnackBar.
- Final `flutter test --no-pub`: all 193 tests passed without updating goldens.
  Existing normal Login baselines still match; only two new error-state
  reference images were added. `git diff --check` passed. Keep diagnostic
  `test/failures/` images and `.codex-attachments/` out of future source commits.
- Replaced deprecated TickerMode.of with the installed SDK's equivalent
  TickerMode.valuesOf(context).enabled API, then reran all nine motion/form tests:
  passed. Final `flutter analyze --no-pub`: no issues found.
- Both ignored private source hashes remain unchanged. No service, migration,
  dependency, live Supabase or native configuration changed in this follow-up.
  Earlier avatar-policy deployment above is historical and remains in place.
- Still local on `codex/buzz-ui-refresh`. No commit, push, APK rebuild, physical
  phone animation test or iOS verification for this follow-up.

## Requested APK After Inline Validation (2026-11-15)

- The user subsequently requested an APK. Built the public/live-Supabase ARM64
  release from the current working sources, including Admin-card PFPs, Profile
  progress, the softer palette, role sheet, resume/read improvements, animated
  dock icons, toasts and the new inline validation/shake behavior.
- Replaced the existing output, without creating another named APK copy:
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  Size: 22,065,511 bytes (about 21 MB). Version name 1.1.0, Android version code
  2012 (`--build-number 12`). This supersedes the version-code-2011 artifact.
- SHA-256:
  `987811155C03C09115F3D9F5227186CE0C1F30A43E375AC380D372D77577BBBD`.
- APK v2 signature and 16 KiB alignment verified. The existing Android debug/test
  certificate is unchanged for in-place update compatibility; the runtime is
  release mode, not a newly configured production-store signing identity.
- Confirmed only the ARM64 app library, the bundled Inter font, and current
  validation text in the package. Known private SOAP operation/hostname markers
  are absent, and the public source scan found no private service imports.
  Neither ignored private source file was changed or deleted.
- The existing Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 future-support warnings
  remain; no native/toolchain changes or validation bypasses were introduced.
- No phone installation/uninstallation, user-data reset, Git commit/push or
  additional Supabase deployment occurred during the build. Physical animation,
  image loading and upload acceptance on the owner's phone remain to be checked.
- Future ARM64 builds should use build number 13 (version code 2013) or higher.

## Profile Media Caching And Recovery Fix (2026-11-15)

- User requested faster banner/PFP loading, the employee's actual PFP in the
  Check-in Logs sheet, and a fix for password recovery remaining on its spinner
  until the app is restarted. Keep all preceding branch work and private files.
- Confirmed Buzz's current `shared/relay/media_disk_cache.dart` uses
  `flutter_cache_manager` with account/community isolation. Adopted that principle
  without importing its Riverpod/relay architecture or changing our Provider API.
- Added `cached_network_image: ^4.0.7` and `flutter_cache_manager: ^3.5.0`;
  lockfile resolves exactly those versions. Added the already-transitive
  `path_provider_platform_interface: ^2.1.3` as a direct dev dependency so disk
  tests use an isolated temporary directory rather than real app storage.
- `services/profile_image_cache.dart` holds one bounded cache per viewer UUID
  (80 objects, unused-file cleanup after one day). Keys also include office
  context for roster/log photos, host and object path. Only the signing query on
  Supabase profile-media URLs is ignored: a newly uploaded UUID filename still
  invalidates the image; unrelated URL query versions remain significant.
  HTTP freshness continues to follow response cache headers.
- `widgets/profile_image.dart` uses CachedNetworkImageProvider for identified
  viewers; local files and anonymous/legacy paths retain their existing loading
  paths. Decode-size limits remain, with no disk resizing/re-encoding that would
  flatten GIFs. Authenticated ProfileHeader, Settings and Admin cards use it.
- `bootstrap.dart` creates the account-scoped ProfileProvider eagerly with the
  viewer UUID; `providers/profile_provider.dart` clears that viewer's disk and
  decoded-image entries when the account scope is disposed. Office switches
  retain the global profile as before. Cleanup is best-effort OS cache cleanup,
  not a guarantee of secure file erasure or permission storage.
- `SupabaseCompanyBackend.profileMedia` signs avatar/banner paths together in
  one Storage request. Missing objects fall back independently; empty profiles
  need no signing request. The banner now keeps its existing gradient visible
  while loading instead of an empty rectangle. Updated only the two Profile
  reference images for that inspected placeholder; layout and colors unchanged.
- `employee_check_ins_sheet.dart` now displays the roster PFP in its employee
  heading. It reuses an existing signed URL/cache entry without another lookup;
  missing photos load once independently of history, with a bounded request and
  initials fallback. Refresh retries the photo; dismissal ignores late results.
  Logs/evidence navigation, sheet springs, haptics and existing sizing remain.
- Root cause of recovery spinner: the root and scoped Supabase backends each
  had their own recovery flag. A successful scoped password update cleared only
  its own flag, leaving AuthProvider's root gate true. Moved the flag into the
  shared session, clear it after confirmed update/context validation or sign-out,
  and retained the authenticated session. Recovery links legitimately establish
  a session; persisted login was not a bypass of password verification.
- Password-update requests now have a 30-second deadline with an explicit
  uncertain-result message; reset-email requests have a 20-second deadline.
  A timeout does not assert that a password change was rolled back. Existing
  inline error/retry, validation and neutral reset-email confirmation remain.
- Added real-SDK mocked HTTP tests for the recovery link, rejected/successful
  updates, shared root/account/office flags, AuthProvider's setup gate and
  batched media signing. Added cache-key/account/office/version tests and a disk
  cache test proving signature rotation reuses original GIF bytes and cleanup
  removes them. Added Logs-avatar reuse, independent loading and retry tests.
- Focused cache/auth/Logs suite: 21 passed. Complete `flutter test --no-pub`:
  all 200 tests passed. Final `flutter analyze --no-pub`: no issues found.
  `git diff --check` passed (only existing CRLF conversion notices).
- No RLS, database migration, Edge Function, attendance submission, captured
  evidence-image caching, SOAP integration, live project or private source edits.
  Both ignored private source hashes remain identical to the preceding APK run.
- Still local on `codex/buzz-ui-refresh`; no commit/push or new APK for these
  changes. The existing version-code-2012 APK does not contain this follow-up.
  A phone recovery-link/network/GIF acceptance check remains necessary.

## Requested 5 MB Profile Limit (2026-11-15)

- User clarified that the GIF exceeds 2 MB and explicitly requested a 5 MB
  allowance, then separately approved applying that limit to live Supabase.
- `services/profile_media.dart` now permits 5,242,880 bytes for all existing
  profile image formats, including animated GIFs, for both avatar and banner.
  The size-error message and matching UI test fixture say 5 MB. Attendance
  evidence and office logos retain their independent 2 MB limits.
- Created `20261115150317_profile_media_size_limit.sql` with the Supabase CLI.
  Its only statement updates `storage.buckets.file_size_limit` for
  `id = 'profile-media'`; it does not alter objects, RLS, MIME types or privacy.
- Added the former-limit/exact-5-MB/5-MB-plus-one-byte GIF boundary checks.
  The isolated PostgreSQL migration/RLS test asserts all three buckets retain
  their original formats/privacy and only profile-media receives the new cap.
  Updated the current backend setup guide; older handoff entries are historical.
- Validation: 14 focused profile-media/cache/UI tests passed; the isolated
  migration/RLS suite passed; Flutter analysis found no issues; diff check passed.
  The preceding complete Flutter run passed all 200 tests before this small
  limit-only change. No real user avatar or attendance record was uploaded for
  testing, and no actual gallery/GIF phone acceptance check has been performed.
- Verified the live bucket was previously private with a 2,097,152-byte limit
  and allowed GIF MIME type. Deployment dry run listed only the new migration.
  Applied that migration to project `xbixwtzyfbardoujghjc` with `--skip-vault`,
  without seeds/roles or unrelated migrations. Live readback confirmed
  profile-media is private, still allows all five image formats, and now has
  `file_size_limit = 5242880`. Both other private buckets remain JPEG/PNG-only
  with `file_size_limit = 2097152`. Private integration sources remain untouched.
- Built the one public/live ARM64 release APK with build number 13 (Android
  code 2013), replacing `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  Size: 22,268,188 bytes (about 21.2 MB). SHA-256:
  `9966AE3E71B32D1CD0219C659FA5D1C3994CBEEA66811BF0160D43B1A66207B9`.
  Older installed APKs still reject files above 2 MB locally and need this update.
  The new artifact also includes cache, Logs-avatar and recovery-state fixes.
- Verified ARM64-only packaging, version name 1.1.0, code 2013, APK v2 signature,
  16 KiB alignment and the same existing Android debug/test certificate used for
  previous in-place updates. This is a release-mode build, not new store signing.
  The compiled app contains the 5 MB validation message and no known private
  SOAP operation/hostname markers. Both ignored private source hashes are intact.
  Existing Gradle/AGP/Kotlin future-support warnings remain; no native toolchain
  upgrade or validation bypass was introduced. Next build should use 14 or higher.
- Source work remains local on `codex/buzz-ui-refresh`; no Git commit/push.

## Publication Checkpoint (2026-11-15)

- User requested documenting all accumulated UI work and pushing the public
  sources with an updated README. Refreshed the repository-root README and the
  app-directory README: functional public features, offline/read-only demo,
  invite-only live access, current design/stack, correct working directory and
  build commands, Buzz credit, and honest Android/iOS verification status.
- Existing mockups are explicitly labeled as an earlier design and placed in a
  collapsible gallery. The user will provide new mockups and a demo video; no
  missing assets, placeholder downloads or fabricated current media were added.
- Added the current-state index at the start of this handoff. It records the
  palette/navigation preservation rules, completed UI and media/auth fixes,
  approved live migrations, current APK, deferred features, and publication scope.
- Final publication validation: all 200 Flutter tests passed after the 5 MB
  change; Flutter analysis found no issues; isolated PostgreSQL migration/RLS
  tests passed; staged diff check and local README link/image checks passed.
- Pre-publication screening found no ignored private files, local artifacts or
  recognizable credential patterns in the staged additions. This is a focused
  publishing check, not a resumed security audit or a claim of complete security.
- Stage only the public source, tests/goldens, two approved forward migrations,
  both READMEs, backend/attribution docs and this handoff. Preserve unrelated
  historical handoff edits, prompt/design notes, attachments and failure images
  unstaged. No APK upload, new backend deployment, main merge or history rewrite
  is part of this publication request.
- Push `codex/buzz-ui-refresh` and open a separate PR based on
  `codex/multi-office-switcher` while #19 remains open. This keeps the new UI diff
  separate from the earlier office migration. After #19 merges, review/retarget
  the UI PR to main as appropriate; do not imply main already contains this work.

### Published Result

- Public source/README checkpoint `ba2ea25778061c04d26297dad1400d4f3584a5f2`
  was committed and pushed to `origin/codex/buzz-ui-refresh`.
- Opened [PR #20](https://github.com/Umerjamshaid/Attendance-app/pull/20),
  "Polish attendance UI, profile media and recovery flows", with base
  `codex/multi-office-switcher`. PR #19 and main were not merged or rewritten.
- The current README is on the UI branch/PR; the GitHub default-branch front page
  will remain on its prior version until the relevant PRs are merged.
- Both ignored private source hashes remain unchanged. The APK is still local.
  The only remaining local edits are the intentionally excluded historical
  handoff, prompt/design notes, attachments and diagnostic images. Do not delete
  or sweep them into an unrelated commit to make the worktree appear clean.
- Next media task: use the owner's forthcoming mockups and real demo video to
  replace the explicitly labeled earlier gallery. Shorebird remains discussion
  only; notifications and recognition badges still await product requirements.
