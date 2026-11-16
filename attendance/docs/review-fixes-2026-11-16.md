# Review And Media Fixes

Date: 2026-11-16 (Asia/Karachi). Branch: `fix/coderabbit-issues`.
Base: `a406336`, the published UI PR #20 checkpoint, which is stacked on #19.

## Verified Findings

- Office updates: still valid. Name/logo actions supplied stale values for the
  other field. New optional-field provider/backend updates call a forward-only
  `update_office_fields` RPC, preserving untouched fields under an organization
  row lock. Original RPC remains available for older installed clients.
- Role dropdown: obsolete on current code. It was replaced by the explicit
  draft role sheet in PR #20. Added visible committed-row assertions for both
  cancelled confirmation and failed server writes; existing retry/success tests
  remain. Do not restore a dropdown or discard editable drafts unnecessarily.
- Owner self-demotion: still valid. The forward migration rejects demoting the
  current owner even with another active admin, while retaining the existing
  last-active-admin protection and authorization/lock ordering. Ownership
  transfer is not introduced by this patch.
- Invitation reissue: still valid. Pending invitations now set `invited_by` to
  the current authorized actor; accepted invitations return before this update.
  Existing first-account versus additional-office acceptance behavior remains.
- Expired avatar URLs: still valid. A shared download layer checks advisory
  expiry only when network bytes are needed, batches re-signing through the
  immutable backend scope and server RLS, and retries 400/401/403 downloads once.
  Decoded/disk cache keys continue to ignore only the signing query for the same
  object version. Token contents are not used to authorize access.
- Late private-cache writes: still valid. A login-scoped cache manager drains
  outstanding operations even if a widget stops listening. Retirement prevents
  new reads, closes its own HTTP client, waits for writes, removes indexed and
  partially-written files, then closes the index. Later login managers wait for
  that cleanup before opening the persistent cache, and use different decoded
  memory identities. Cache cleanup is not a claim of forensic secure erasure.

## Media Behavior

- Admin data refreshes preserve existing avatar references until the new batch
  completes; confirmed missing photos clear them. Returning to the roster/Logs
  sheet can use the same decoded and disk entries without flashing initials or
  redownloading unchanged bytes. Attendance refresh itself is not disabled.
- A failed signing result is omitted rather than returned as a false null
  removal. ProfileProvider keeps a currently visible banner on an incomplete
  refresh, but still honors explicit removal. Cached GIFs can remain usable when
  a signing refresh is temporarily offline.
- Banner image identity is stable across signature rotation, and playback uses
  gapless replacement. A failed image now exposes a compact, accessible Retry
  banner action above the cover-image tap target; explicit retry evicts corrupt
  cached bytes and reloads. No screen/layout or palette redesign was performed.
- The user's 3 MB GIF file/device logs were not supplied during investigation.
  They clarified that playback stopped and the app's default blue banner became
  visible, not that the GIF's pixels changed. That is the existing fallback, not
  evidence of Storage corruption. Expiry/refresh failure paths are reproducible;
  the exact phone incident and potential decoder/memory-pressure contribution
  remain unconfirmed until the original file or logs are available.
- GIF banners: app limit is 10,485,760 bytes. Avatars and non-GIF banners remain
  5,242,880 bytes in app validation; office logos and evidence remain 2 MB.
  Storage buckets have one size ceiling, so profile-media's bucket ceiling is
  10 MB, not by itself a per-kind enforcement mechanism. The follow-up below
  adds a server guard. No MIME or RLS access expansion is part of the size
  migration. Original GIF bytes are retained.

## Storage Recommendation

Keep Supabase Storage for this app. Original image/GIF delivery is compatible
with the current private-object model; moving providers would not fix stale
signed URLs, client cache lifetime, or Flutter decoding errors. The app does not
request server-side image transformations for animated media.

- [Standard uploads](https://supabase.com/docs/guides/storage/uploads/standard-uploads)
  support these file sizes; Supabase recommends resumable TUS uploads above
  6 MB for reliability. This patch keeps the existing standard upload flow;
  weak-network/resumable upload work is a separate enhancement, not completed.
- [Private signed URL caching](https://supabase.com/docs/guides/storage/cdn/smart-cdn)
  requires attention to token lifetime and cache identity. Do not assume Smart
  CDN is enabled on this project or make private buckets public for performance.
- A specialist media pipeline would be worth evaluating later for extensive
  transcoding/optimization/video needs, not as a workaround for this fallback.

## Rollout And Boundaries

- The user explicitly approved deploying these tested forward migrations to the
  live project. Do not edit the already-applied multi-office or 5 MB migration.
- Pre-rollout dry run listed only `20261115210348_office_review_fixes.sql` and
  `20261115212524_gif_banner_limit.sql`. The pre-rollout ERROR-level security
  advisor check reported no issues. Final rollout/results are recorded below.
- Keep Provider, CompanyBackend, preview isolation and private submission wiring.
  Do not stage ignored private files, API notes, new unreviewed mockups/ZIPs,
  attachments, failure images or unrelated historical handoff/design notes.
- All source fixes belong on this single branch. Do not merge main or silently
  push changes into the heads of PR #19/#20. A review PR can be stacked on #20.
- No full security audit/subagent restart, notification system, Shorebird
  integration or storage-provider migration is part of this request.

## Verification And Deployment

- Full Flutter suite: 210 tests passed. After the final response-stream
  retirement guard, all 7 cache regression tests passed again.
- Final Flutter analysis: no issues found. Isolated PGlite migration/RLS suite
  passed, including legacy preservation, office isolation, role protection,
  invitation retries and partial office updates.
- Both forward migrations above were applied to the explicitly approved live
  project on 2026-11-16. Readback confirmed both migration versions, the owner
  guard, current invitation actor, and authenticated-only partial-update RPC.
  The internal invitation completion function remains service-only.
- Post-deployment ERROR-level database advisors: no issues found. Readback
  counts remained 2 organizations, 6 memberships, 5 profiles, 11 check-ins and
  19 Storage objects. All three media buckets remain private; evidence/logos
  remain 2 MB, and profile-media is now 10 MB with unchanged MIME types.
- A read-only metadata check of the reported banner found the referenced GIF
  still present: image/gif, 3,695,090 bytes. No private media was downloaded.
  This rules out a currently missing object, not every possible phone decoder
  or memory issue. Original GIF/phone logs are still needed for that diagnosis.
- Ignored private entrypoint/service hashes are unchanged. No APK was rebuilt
  in this pass; the previous APK does not contain these client-side fixes.
  Physical-phone GIF playback and optional CodeRabbit CLI review remain unrun.
- Public fixes were committed as `2735132` on `fix/coderabbit-issues` and pushed.
  [PR #21](https://github.com/Umerjamshaid/Attendance-app/pull/21) targets
  `codex/buzz-ui-refresh` (PR #20). No existing PR head or main was overwritten.

## PR 21 Follow-Up

All nine submitted inline findings were verified as valid (two describe the
same cleanup failure and two concern different banner callback races).

- Cleanup always disposes the underlying manager in `finally`. `_retiring`
  stores a fulfilled namespace barrier, not a rejected cleanup future. On a
  filesystem failure the next login waits, then uses a new namespace rather
  than reopening the partially cleaned cache. Later successful cleanups retain
  that safe namespace. Old OS-locked bytes may remain; this is isolation and
  best-effort cleanup, not secure erasure.
- Partial-file tracking is deduplicated by path and drops files once indexing
  succeeds. Existing cached files read/evicted later are not added to that set.
  A regression exercises 100 indexed/read/evicted files without accumulation.
- Avatar refresh results now distinguish a confirmed absent path (`UUID: null`)
  from a failed/omitted signing result (UUID omitted). Only confirmed removal
  clears the cached avatar. Backend batching and office validation remain.
- Banner failure callbacks capture the generation at Image construction, so
  outgoing AnimatedSwitcher children cannot mark the new banner failed.
  Signature changes clear Retry without replacing the stable image element;
  explicit Retry still gets a separate image revision to reload corrupt bytes.
- The missing-file UI test waits for the Retry tooltip with a bounded deadline,
  not a fixed 80 ms delay. Added a cache-backed test of signature refresh and
  late outgoing errors; the existing light/dark goldens remain unchanged.
- The logo-clear SQL test immediately asserts `logo_path IS NULL`.
- New forward migration `20261115222312_profile_media_kind_limits.sql` validates
  profile-media sizes using Storage's measured `size`/`contentLength`, object
  filename and reported MIME type, including privileged completion writes.
  Avatars/non-GIF banners are capped at 5 MiB; named GIF banners at 10 MiB.
  Metadata-less preflight probes remain compatible. This is not byte sniffing;
  user-supplied custom metadata cannot change the guard's measured size input.
  No object migration/deletion, bucket split or RLS relaxation is performed.
- Forward compatibility migration
  `20261115224246_profile_media_upload_probe_compatibility.sql` limits the hook
  to final metadata containing measured `size`. Multipart authorization probes
  can report Content-Length including request overhead. Tests cover rolled-back
  probes above each cap and final measured sizes exactly at/above the caps.
- This custom trigger is intentionally narrow; Supabase recommends treating
  the Storage schema as managed. Its API metadata contract and trigger must be
  rechecked on Storage upgrades. See backend-setup.md for rollback boundaries.
- The user explicitly approved applying the tested guard live and requested a
  single public ARM64 release APK. Deployment/build results are recorded below.

### Final Follow-Up Delivery

- Source/migration fixes: `36fd27b`, pushed to `fix/coderabbit-issues` / PR #21.
  All nine original review threads received a fix/test explanation and were
  resolved; none of the submitted findings was dismissed as invalid.
- Final full Flutter suite: **213 tests passed**. Final analysis: **no issues
  found**. Disposable PGlite migration/RLS tests passed again with the measured
  size, malformed metadata, renamed object and multipart-probe boundary cases.
- Both new forward migrations were applied to the approved live project.
  Readback verified their history entries and the trigger's measured-size WHEN
  condition. Counts remain 19 Storage objects, 11 check-ins and 6 memberships;
  the media buckets remain private. Final ERROR-level advisors found no issues.
- One public Supabase ARM64 release APK was rebuilt in the existing location:
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 22,268,188 bytes
  (about 21.2 MiB), version name `1.1.0`, build argument `14`, APK version code
  `2014`. This replaces the previous build at that path; no extra variants were
  generated. Package remains `com.example.attendance`.
- APK SHA-256:
  `1FF44392BC95757787F925C413BBBAFEEF5BA9C10080518BC59E195DC1F86230`.
  Alignment and APK v2 signature verification passed. Signing certificate
  SHA-256 remains
  `400660b609acea3238e627da073865006229e231cf9d1f71b6a89e4548851520`.
  It is the existing Android test/debug signing key for in-place test updates,
  not a configured Play Store production signing setup. Runtime build is release.
- Private source hashes remain unchanged. Unrelated handoff edits, attachments,
  mockups and API/private files were left unstaged. No app uninstall/data reset.
- Physical-phone GIF playback, live end-to-end upload testing and optional
  CodeRabbit CLI review remain unrun. Existing Gradle/AGP/Kotlin future-support
  warnings are documented, not bypassed or upgraded as part of these fixes.

## Durable Cleanup And Current Gallery

- The follow-up namespace-retention finding was valid. Isolation alone avoided
  failed-login image loads but abandoned the previous namespace after a purge
  error. `ProfileCacheCleanup` now retains failed namespaces in a serialized
  SharedPreferences queue and retries at app startup, subsequent image use and
  sign-out. Successful purges remove their queue entries; failures remain queued.
- Namespace selection checks the persisted queue before opening the normal
  cache, including after a restart. A namespace being purged is not reused by
  a new login. Retries do not block the active session on old-file deletion.
- Retry cleanup reopens the retired cache index, disposes its manager, and also
  removes flat partial files in that exact namespace. Names are validated;
  directory links are rejected before deletion, and cleanup never recurses into
  other directories. Active namespaces and attendance evidence are untouched.
- If preferences are unwritable too, failures remain queued in memory until
  persistence can succeed. Persistent OS locks can still prevent deletion;
  this is app-level retry, not a claim of forensic secure erasure.
- Added tests for restart recovery, repeated purge failures, concurrent queue
  additions, non-blocking namespace selection, and indexed/partial-file removal
  without touching an active namespace. Existing late-download tests remain.
- The requested remote-only CodeRabbit CLI review completed on public commit
  `66cc408` against `codex/buzz-ui-refresh`, returning one minor malformed-query
  finding. It was reproduced locally and is now fixed by moving query decoding
  inside the FormatException handler, with a `token=%FF` regression assertion.
- The missing-results documentation finding is stale: `66cc408` already added
  the Final Follow-Up Delivery section immediately below the referenced pointer.
- The root README now leads with the five corrected, current Android mockups
  under `screenshots/current/`. Captions, public demo instructions, feature copy,
  Buzz attribution and verification limitations are kept concise. Old screenshots
  and the supplied ZIP are preserved; no image was modified or generated.
- The previously built ARM64 APK (code 2014) predates this cleanup/parser change.
  No new build or live Supabase change is part of this follow-up.
- Final validation for this follow-up: 216 Flutter tests passed, analyzer found
  no issues, and all five 1320x2868 PNG gallery paths and relative documentation
  links resolve. Private entrypoint/service hashes remain unchanged. These
  changes stay on `fix/coderabbit-issues` / PR #21, not a merge into main.
