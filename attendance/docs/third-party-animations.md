# Buzz Animation Attribution

Office switcher animation portions are adapted from Block Buzz, Copyright 2026
Block, Inc., licensed under Apache-2.0. The complete upstream license is bundled
in `assets/licenses/Buzz-Apache-2.0.txt` and registered in Flutter's license list.

Upstream sources:

- https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher.dart
- https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher_action.dart

Modified for this project: native StatefulWidget controllers instead of hooks,
Provider-backed office selection, bottom-sheet-local coordinates, a return-to-grid
flight instead of auto-dismissal, existing Tabler icons/theme, device-only office
visibility preferences, and reduced-motion/accessibility tests. No Buzz backend,
identity, relay, pairing or community deletion code is used.

The switcher alone uses the bundled Inter variable font (`Office Inter`), with
24 px / 600 titles and 16 px / 600 office labels. Other screens retain their
existing typography. Inter is licensed under SIL Open Font License 1.1; its
copyright notice and complete license are bundled in `assets/licenses/Inter-OFL.txt`
and registered in Flutter's license list.
