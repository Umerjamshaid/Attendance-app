# History Subgroups Prototype - 2026-11-17

## Scope

- Local branch: `codex/history-subgroups-prototype`, based on Admin-chip commit
  `66d0629`. The completed badge prototype is preserved. Do not push either UI
  prototype or rebuild an APK without a further request.
- Only History's date-group presentation changes. Home, Admin, employee Logs,
  Profile, navigation, providers, statistics, uploads and access rules are unchanged.
- Portal Labs cloned at `D:\work\APP flutter\portal-labs`, beside Buzz and the
  badge reference repo. Origin: `https://github.com/lportals/portal_labs.git`;
  revision `10f2159`. The clone is unmodified; no repository scripts were run.

## Adaptation

- Adapted Portal Labs' MIT Scrollable Subgroups into the existing History
  viewport, rather than nesting a second scroll view or installing the library.
- Date headers pin beneath History's app bar. Outgoing groups fade on collision
  with the next date, and header bottom corners round as their records leave.
  Reduced motion disables the collision fade while retaining native pinning.
- Groups use existing Buzz-inspired `surfaceContainerLow`, 22dp corners, bundled
  Inter typography, restrained labels and existing row/divider spacing. Dates now
  sit inside their group's gray surface. Record content and semantics are reused.
- Headers grow with text scaling. Rows use a lazy SliverList; no tap actions or
  new gestures were added. Pull-to-refresh, the single ScrollController and the
  existing page-state preservation remain intact.
- Per-date geometry state is keyed by date, resynced on data changes, and disposed
  on removal. Geometry reads happen once after layout per scroll frame; opacity
  and radius notifiers rebuild only the small affected surfaces.
- Source attribution and MIT notice are bundled in
  `assets/licenses/PortalLabs-MIT.txt`. No packages, lockfile or backend changes.

## Verification

- Five new widget cases cover light/dark visuals, pinned positions, collision
  fade/rounding, 320dp and wide screens, 2x text, RTL, reduced motion, same-count
  group replacement, and existing loading/error/empty/refresh states.
- New previews show unscrolled and pinned History in both themes. All were
  inspected. The existing two History overview screenshots were updated only
  for the explicitly requested date-group appearance.
- Compared the old and new History golden images: every pixel in the top 320px
  (the app bar and full overview) is identical in both light and dark themes.
  Original comparison copies are ignored under `.dart_tool/history-subgroups-reference`.
- The 13 focused History/navigation tests and two overview tests passed.
  Final analyzer: no issues. Final full regression suite: all 230 tests passed.
- Private entrypoint and SOAP service hashes match their original values. The
  user's existing `docs/ui-handoff.md` edits and all unrelated files stay unstaged.
- No live deployment, external reviewer submission, APK build or physical-phone
  testing. The inherited Discord Admin badge still requires replacement or reuse
  clearance before public distribution.
