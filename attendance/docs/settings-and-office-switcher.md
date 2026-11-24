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
gate checks the installed version against `last_seen_release` in local
preferences. Dismissing the sheet records that version. Rebuilding the same
version does not reopen it. A fresh install seeds the preference quietly;
updates from older builds without the preference use OS install/update times
when available. This check never holds the splash or interrupts password setup.

Both views render Markdown with `gpt_markdown` and show the installed
version and build. On release, publish a stable GitHub Release with the tag
`android-<version>-<build>` for build-specific notes, or `v<version>` for notes
that apply to every build of that version. The app checks the 30 most recent
releases only when the sheet or Settings notes open, never selecting a different
version or build. It checks again after 24 hours on success or six hours on a
miss or error. No token is needed in the app. Cached notes are used if a later
request fails. Keep a bundled fallback in `lib/screens/profile/whats_new_screen.dart`
for the upcoming version so first offline launches have notes, too.

For every public update, bump the semantic version and build number in
`attendance/pubspec.yaml` and add matching bundled notes and a changelog entry.
Check the built APK's manifest before tagging; Flutter adds 2000 to the base
build number for ARM64 split APKs. For example, `1.1.1+2028` becomes Android
version `1.1.1`, version code `4028`, tagged `android-1.1.1-4028`.
Use the same APK delivery format and signing key for upgrades.

## Foreground Notifications

`InAppNotificationHost` displays one queued banner above the app dock, below
modal routes and away from the existing top-edge toast. After applying the
`office_check_in_realtime` migration, active office admins subscribe to their
private office/user topic. A verified check-in refreshes the inbox; another
employee's new check-in can also show a banner that opens Check-in Activity.
The broadcast carries only a check-in ID, and the admin-only feed RPC still
authorizes the details. The channel closes when the app backgrounds, signs out,
or changes office. Reconnection and manual refresh catch up the inbox without
replaying old banners. No Firebase or background push was added. Portal Labs'
stacked toast informed the motion; its collapsible
panel is better suited to a future inbox summary. The banner uses original
Flutter code and the app's motion tokens.

The inbox uses Buzz-style All and Unread views over Attendance's authorized
check-in feed. Read markers stay local to the device and office. Buzz's chat
events, relay transport, and thread read-state model are not used.

## Offline And Device Insets

The dock uses the system view insets and a shorter control height in compact
landscape windows. A disconnected launch opens a local screen with Demo,
Appearance, and About. An already verified session keeps its shell, with live
office actions locked until the backend is reachable again. The app does not
restore cached office permissions or queue check-ins offline.

About saves the bundled CV through the native Android or iOS file dialog.
Updating the CV requires replacing the bundled PDF in a new build.

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
