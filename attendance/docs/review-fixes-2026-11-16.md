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
