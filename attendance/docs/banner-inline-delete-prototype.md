# Banner Inline Delete Prototype - 2026-11-17

## Scope

- Local branch: `codex/banner-inline-delete`, based on search/tag commit
  `e361011`. Earlier History, Admin-chip, search and tag prototypes are preserved.
- Only the existing Profile banner's remove interaction changes. The user asked
  to try Portal Labs Inline Delete and include its component animations, then
  build one APK with all current work.
- No provider/backend implementation, upload limits, image caching, office
  permissions, database schema or private attendance source changes.

## Interaction And Animation

- The existing trash action opens a compact Banner menu with Change banner and
  Remove banner. Tapping the banner itself still opens the existing picker.
- Remove banner replaces its row with inline Remove / Cancel actions. Nothing
  is deleted before confirmation. Cancel reverses the row animation; close,
  Android back and outside tap leave the banner unchanged.
- Adapted the actual MIT component and showcase from sibling Portal Labs clone
  revision `10f2159`, rather than substituting a standard confirmation dialog:
  - 320ms popup fade/scale, from 0.9 to 1 with Cubic(.23, 1, .32, 1).
  - Staggered 15dp row entrance with the reference's interval/ease-out timing.
  - 500ms inline row slide/crossfade using the component's spring values:
    mass 1, stiffness 220, damping 26.
  - 100ms press scale to 0.95, native ink feedback and light-impact haptics.
- Colors, Inter typography, Tabler icons and corners use the existing Profile
  theme. Confirmation buttons have 48dp-or-larger targets. Large text stacks the
  buttons vertically; the popup can scroll on short screens. Reduced motion
  skips the popup, row and press movement.
- `PortalSpringCurve` now accepts the reference's spring parameters while
  preserving the previous defaults used by search and tags.
- Confirmation is guarded against repeat activation. Banner actions show a busy
  state while removal is pending. A changed banner/account invalidates an old
  open menu, preventing it from removing a replacement image.
- The existing ProfileProvider removal and success/error toast paths are reused.
  A failed removal keeps the current banner. No image-cache identities change.
- MIT attribution extended in `assets/licenses/PortalLabs-MIT.txt`.

## Verification

- Nine new widget cases cover the two-step flow, cancel/close/outside/back,
  duplicate confirmation, pending state, failure preservation, gallery action,
  stale-menu protection, actual mid-animation movement and 320dp / 2x text /
  reduced motion in light and dark modes.
- Four new menu/confirmation golden previews were visually inspected. Existing
  Profile, search, tags, History and other golden baselines remain unchanged.
- Final Flutter analysis: no issues. Full regression suite: all 252 tests passed.
- Private entrypoint and SOAP service hashes match their original values. The
  public Dart source reference scan found no private entrypoint/service imports.
  Existing user edits in `docs/ui-handoff.md` remain untouched and unstaged.
- Existing Android Gradle / AGP / Kotlin future-support warnings are not changed
  or bypassed. No unrelated toolchain upgrade was attempted.
- No push or live deployment. Physical-phone animation and haptic feel still
  require owner testing. The inherited Discord badge remains prototype artwork
  and needs replacement or reuse clearance before public distribution.

## APK

- One public/live ARM64 release test APK was requested. It uses `lib/main.dart`
  with the existing public Supabase client configuration, not the ignored SOAP
  entrypoint. No secret/service-role credentials are bundled.
- The build retains the existing application ID and local test signing key and
  increments the build argument to 16 for updates without uninstalling.
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Size: 22,860,892 bytes (21.80 MiB). Release runtime, ARM64 only; version name
  `1.1.0`, APK version code `2016`, package `com.example.attendance`.
- SHA256: `384C473F1A87D25B5E3CF8B56E8AC0CE6C37AAA9D30AE56DF84D105F026AD8A6`.
- APK v2 signature and 16 KiB alignment checks passed. Certificate SHA256
  `400660b609acea3238e627da073865006229e231cf9d1f71b6a89e4548851520`
  matches the previous test APK. This is the existing debug/test certificate,
  not a Play Store release-signing setup.
- Includes all local prototypes up to this branch. The previous artifact at the
  same path is replaced; no additional APK variants were generated or copied.
