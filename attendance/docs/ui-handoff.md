# Home And History UI Handoff

Updated: 2026-11-06. Branch: `codex/backend-addition`.
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
- No APK is built as part of this UI-only task. The earlier test APK does not
  include this restoration; build a fresh one when requested.
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
