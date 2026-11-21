# Settings and Office Switch

## Office switch performance

Two sources of unnecessary opening work were identified in the Flutter code:
the tap started a full office reload and notified listeners while the route was
entering, and the eager grid extracted a Material palette for each available
logo. Signed logo URLs and image caching already existed; palette extraction
was separate work even when the logo itself was cached.

- `OfficeProvider` keeps a one-minute in-memory snapshot per signed-in account.
  Opening the sheet shows that snapshot immediately. A stale snapshot refreshes
  after the entrance; cold startup populates it as before.
- Concurrent requests share a reload. Offices and invitations load concurrently.
  Account/scope changes and completed mutations invalidate superseded reloads.
  Displayed memberships are not authority for any office action; server
  authorization and the office-scoped navigation reset remain unchanged.
- The sheet builds rows lazily, uses the existing image cache with a theme-based
  logo border, and scales a stable avatar child during the selection animation.
  Home and the office navigator subscribe only to the fields they display/use.

## Settings sheets

The four sheets share a floating Material surface, a short slide, drag and
scrim dismissal, and a scrollable body for large text. Reduced motion disables
the entrance and exit animations. Sign out requires confirmation and still uses
`AuthProvider.logout()`. Help provides email and GitHub actions with a clipboard
fallback. About reads the installed platform version; the maker sheet uses the
existing local credit photo. Contact strings live in `AppInfo`.

## What's New

Settings shows the changelog for the installed version. On Home, the launch
gate checks the installed version and build against `last_seen_release` in
local preferences and shows the highlights once for a newer build. Dismissing
the sheet records that build. A fresh install seeds the preference quietly;
updates from older builds without the preference use OS install/update times
when available. This check never holds the splash or interrupts password setup.

For new releases, update the notes and highlights in
`lib/screens/profile/whats_new_screen.dart` and the public `CHANGELOG.md`.

References reviewed: [Buzz's community switcher](https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher.dart)
keeps cached content and avatar painting independent from animation;
[BunPod's confirmation](https://github.com/kamranbekirovyz/bunpod/blob/main/lib/common/widgets/styled_sheet.dart)
and [maker sheet](https://github.com/kamranbekirovyz/bunpod/blob/main/lib/features/menu/widgets/developer_sheet.dart)
provided interaction references. The new Settings sheets use original Flutter
widgets, not BunPod's code or assets.

## Verification

From `attendance`:

```powershell
flutter analyze --no-pub lib test
flutter test --no-pub --coverage --coverage-path=build/settings-office.lcov test/app_theme_test.dart test/settings_screen_test.dart test/public_settings_test.dart test/office_provider_test.dart test/office_switcher_test.dart test/office_switcher_motion_test.dart test/office_bootstrap_test.dart
```

For device checks, run a profile build with several logo-bearing offices and
compare first open and repeat opens in the Flutter DevTools frame timeline.
Check sign-out cancellation and the external mail and browser handlers on
physical Android and iOS devices.
