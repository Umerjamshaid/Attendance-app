# Buzz Design And Animation Attribution

Design and animation portions are adapted from Block Buzz, Copyright 2026
Block, Inc., licensed under Apache-2.0. The complete upstream license is bundled
in `assets/licenses/Buzz-Apache-2.0.txt` and registered in Flutter's license list.

The shared UI adaptation references
`59ae028a360242d43ffbfdafca8a76eda00484d9`; the separate reference checkout was
subsequently updated to `69742376a9b1b15da62295f54a053913540722c1` for the
resume/read-coalescing follow-up. The office switcher was originally
adapted from `920b1e64bdd05c6605a2562b5b05618bc8bb264a`; this UI refresh does not
replace its existing selection, visibility, or authorization behavior.

Office switcher sources:

- https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher.dart
- https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher_action.dart

Modified for this project: native StatefulWidget controllers instead of hooks,
Provider-backed office selection, bottom-sheet-local coordinates, a return-to-grid
flight instead of auto-dismissal, existing Tabler icons/theme, device-only office
visibility preferences, and reduced-motion/accessibility tests. No Buzz backend,
identity, relay, pairing or community deletion code is used.

Shared design and feedback sources (under `mobile/lib/shared/`):

- `theme/color_scheme.dart`, `theme/text_theme.dart`, `theme/app_theme.dart`,
  `theme/grid.dart`, and `theme/utility_surface_theme.dart`.
- `widgets/buzz_toast.dart`, `widgets/toast_capsule_content.dart`,
  `widgets/buzz_toast_host.dart`, and `toast_haptic.dart`.

Modified for Attendance: existing Provider architecture and screen contents,
bundled/offline Inter typography, zero letter spacing, accessible attendance
status colors, and flat theme-aware controls. Settings reuses Buzz's utility
surface inversion without changing account actions. Existing Tabler icons stay;
only the four dock destinations use `flutter_lucide_animated` (MIT) on selection.
Attendance's charcoal/gray surfaces and teal accents replace Buzz's pure-black
palette while retaining its semantic color roles. Resume/read coalescing and the
office role sheet adapt the reference's interaction principles to existing
Provider and server-authorized operations; no Buzz role or identity backend is
copied.

Toast feedback uses native StatefulWidget controllers, the standard capsule
reveal and slide curves, one active notice, reduced-motion handling, and Flutter
haptics. Existing message/action/timeout payloads are retained. Office changes
clear notices and invalidate late feedback without replacing the navigator.
Large-text actions stack; long messages can scroll. The selected app theme is
respected instead of forcing system brightness. Buzz's iOS Dynamic Island shader,
platform-view workaround, reconnect features, and native haptic channel are not
ported; Attendance uses the standard Flutter capsule on every platform.

Inter is registered globally as `Inter`; the `Office Inter` alias remains for
the unchanged switcher. Inter is licensed under SIL Open Font License 1.1; its
copyright notice and complete license are bundled in `assets/licenses/Inter-OFL.txt`
and registered in Flutter's license list.

Inline validation additionally adapts
`features/pairing/pairing_page/pairing_error_shake.dart` and the error-text pattern
in `community_link_form.dart`, inspected at `69742376a9b1b15da62295f54a053913540722c1`.
The 280ms duration, 0/6/-6/4/0 horizontal stops, per-leg weights, and
`Cubic(0.22, 1, 0.36, 1)` are retained. Attendance uses a disposable StatefulWidget
controller instead of hooks, replays on explicit validation attempts, stops for
reduced motion/offscreen widgets, and retains native field semantics and focus.
No pairing, community-link parsing, identity or validation rules were copied.
