# Admin Chip Badge Prototype - 2026-11-17

## Agreed Scope

- Local branch: `codex/admin-badge-prototype`, based on the completed logo fix
  `9a3b5e7`. Do not push this artwork prototype or add it to the existing PR.
- Only replace the current icon inside Profile's existing Admin chip. The
  "Admin" text, position, 12/6 padding, background, pill radius and 6dp icon gap
  stay unchanged. No badges beside names, on Admin cards, or in Logs sheets.
- No new profile views, award records, badge provider, Staff/streak badges,
  backend API, membership permissions, migration or live deployment.

## Implementation

- `profile_header.dart`: `_InfoChip` accepts a leading widget instead of just
  IconData. An active admin uses a 16dp bundled SVG; every other role keeps the
  existing 16dp ID icon. Tags and the attendance-status pill are unchanged.
- Badge visibility follows the existing office-scoped Employee role and active
  state supplied through Provider. It is not an editable tag or stored flag.
  Switching offices updates the badge through the existing auth notifications.
- Asset: `assets/badges/admin-prototype.svg`, copied unchanged from
  `discord-badges/assets/discord-mod.svg`. It loads locally, without a signed
  URL or network request. The readable role label provides its meaning; the
  decorative SVG is excluded from duplicate screen-reader announcements.
- Added exact `flutter_svg: 2.3.4` and its required vector dependencies. Its
  compiler requires `xml <=7.0.1`, so resolution moves XML from 7.1.0 to 7.0.1.
  No other existing dependencies or SDK constraints were changed.
- The collection's MIT notice and source attribution are bundled under
  `assets/licenses/DiscordBadges-MIT.txt`. This does not establish rights to
  Discord's artwork. Replace it with original Attendance artwork or confirm
  reuse permission before public distribution.

## Checks

- Four new widget tests cover the actual SVG asset, 16dp dimensions, unchanged
  chip decoration/gap, employee and inactive-admin fallback, editable-tag
  isolation, and admin-office to employee-office to admin-office switching.
- Light/dark visual baselines are new files only. Their capture waits for the
  SVG to finish rendering. Both were visually inspected, including the shield.
- Both themes also pass at 320dp with 2x text. Existing goldens are not updated.
- Ignored private entrypoint and SOAP service hashes remain unchanged. User
  edits in `docs/ui-handoff.md` and unrelated untracked files are preserved.
- No APK rebuild, push, production changes or physical-phone verification.
- Final verification: all 225 tests passed with existing goldens unchanged;
  `flutter analyze --no-pub` reported no issues. This includes the four new
  badge tests and the existing profile, office, image-cache and backend tests.
- Saved in a local-only prototype commit. No CodeRabbit/external review was
  requested for the third-party artwork prototype.
