# Search And Tag Selection Prototype - 2026-11-17

## Scope

- Local branch: `codex/search-tags-prototype`, based on History prototype
  `079cdd2`. The earlier History and Admin-chip prototypes remain intact.
- User approved both Portal Labs component ideas: employee search and tag
  selection. Only Admin's Employees page and Settings' Profile details change.
- No packages, database migrations, backend calls, permissions or private
  attendance files change. No push, deployment or APK rebuild was requested.
- The inherited Discord Admin-chip artwork is still a local prototype. Replace
  it or clear its reuse before public distribution.

## Employee Search

- `EmployeeDiscoveryBar` adapts Portal Labs' two morphing search/filter surfaces
  to the existing theme, bundled Inter font, Tabler icons and selection haptics.
- Search opens and focuses only after tapping its icon. Closing clears the
  query, dismisses the keyboard and keeps the selected access filter.
- All / Active / Inactive filter the already loaded office roster. Search is
  live, case-insensitive and matches name, employee number, department or email;
  every whitespace-separated term must match.
- Typing and filtering reuse the existing employees Future. They do not query
  the backend. The existing invitation, confirmation, activation, loading,
  error and retry flows remain unchanged.
- Empty results offer Clear filters. Search and filters are controlled by the
  page, including resetting the visible text controller.

## Tag Selection

- `ProfileTagSelection` adapts the reference's keyed, spring-positioned tags.
  Selected tags and suggestions share one animated layer. Native InputChip and
  ActionChip retain keyboard, touch, tooltip and disabled-state behavior.
- Selection stays in the existing Profile details form, not in a second local
  selection model. Nothing is saved until Save changes.
- Optional starter suggestions: Teamwork, Mentor, Problem solving,
  Communication, Leadership and Organized. Existing/custom tags remain editable;
  removing a tag makes it available to add again during that edit session.
- Existing comma-separated custom entry, case-insensitive deduplication,
  12-tag / 40-character limits, inline errors, save failure handling, disabled
  unchanged Save button and discard confirmation are preserved.
- Tags are personal profile metadata, not office roles or badge permissions.

## Motion And Layout

- Both components use the existing 320ms entrance duration and a lightly damped
  position spring matching the app's page spring. Reduced motion sets the
  animation durations to zero. No new animation package is needed.
- Tag measurements respect text scaling and RTL; long labels wrap to two lines
  and then truncate with a full-label tooltip. Tap targets are at least 48dp.
- Large-text filters can scroll horizontally instead of clipping labels.
- Portal Labs source: sibling clone `D:\work\APP flutter\portal-labs`,
  revision `10f2159`. MIT attribution extended in the existing bundled license.

## Verification

- Thirteen new widget tests cover live search fields, combined access filters,
  clear/focus behavior, no extra requests, activation confirmation, invitation
  navigation, fetch retries, controlled tags, custom entries, capacity, save
  failure/busy states, discard, spring motion, RTL, 320dp, 2x text and reduced
  motion in both themes.
- Six new golden previews cover the components and both integrated screens in
  light/dark themes. They were visually inspected. Existing form assertions are
  unchanged; the Settings test now scrolls and waits for the added tag animation.
- Final analyzer: no issues. Full Flutter regression suite: all 243 tests passed
  (`flutter test --no-pub --concurrency 2`). Existing golden baselines did not
  change. `git diff --check` passed.
- Private entrypoint and SOAP service SHA256 values match their starting values.
  Existing `docs/ui-handoff.md` edits and unrelated files remain unstaged.
- Not tested on a physical phone. No external reviewer or live service was used.
