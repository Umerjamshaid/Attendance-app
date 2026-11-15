# Multi-Office Handoff

## Scope And Status

Office is the UI name for `public.organizations`. Provider and `CompanyBackend`
remain the application architecture. The Home profile header is replaced by an
office selector; Profile editing, Home/History summaries, the floating dock,
camera/GPS verification, and the private startup/service are not redesigned.
Broader Buzz/onboarding work remains on hold. No sub-agents were used.

The initial implementation was local source plus a forward-only migration.
After explicit owner approval, the migration and matching functions were deployed
to the existing hosted pilot; see **Approved Live Rollout** below. Other projects
must still complete the coordinated rollout before using this client.
Feature branch: `codex/multi-office-switcher`. The existing unrelated handoff
edits, prompts and design-analysis files are deliberately outside this commit.

## Data Model

- `organizations`: reuses IDs, names, timezone, attendance window and creation
  timestamps; adds nullable `logo_path`, `created_by`, and `updated_at`.
- `memberships`: adds a surrogate UUID primary key. The existing unique
  `(organization_id, user_id)` and `(organization_id, employee_code)` constraints
  remain. Employee numbers and historical attendance are not rewritten.
- `profiles`: remains one row per Auth UUID. Its foreign key now references
  `auth.users`, rather than the old user-only membership key. Names, tags,
  avatars and banners are shared across a user's offices.
- `submission_attempts`: adds/backfills organization context; its key and
  membership foreign key now include the organization. A request ID in one
  office cannot consume or release another office's submission lease.
- `user_office_preferences`: one server-side preference per Auth UUID. A
  composite foreign key binds the selected organization to that same user's
  membership. RPCs and RLS additionally require that membership to be active.
- `employee_invitations`: preserves existing rows; adds inviter and acceptance
  timestamps. Previously completed invitations are backfilled as accepted.
- `office-logos`: private JPEG/PNG bucket, maximum 2 MiB. Member reads and admin
  inserts are checked per office. There is no public bucket or client delete
  policy. Retention removes unreferenced logos after one day.

Legacy `created_by` values remain null: old membership timestamps do not prove
ownership, and the migration must not grant an arbitrary administrator new
promotion rights. The project owner must explicitly assign the intended existing
owner on the disposable copy and repeat that approved assignment at rollout.
Ordinary existing admin permissions remain available without that assignment.
New offices record their authenticated creator atomically. Ownership transfer
remains an explicit project-owner administrative operation.

## Authorization And Operations

- `my_offices`: only the caller's active memberships, with office-specific roles.
- `resolve_office_context`: restores a valid preference; revoked preferences
  fall back to another active membership, or return no authorized employee.
- `switch_office`: locks the account preference, verifies active membership,
  persists selection and returns the selected office's employee/role.
- `create_office`: requires an existing active administrator in at least one
  office. Office creation and the creator's initial `ADMIN001` membership are
  one transaction. Public self-registration and unrestricted joining remain off.
- `update_office`: active office admins may rename/change its logo.
- `set_office_role`: only the active, selected office's creator/owner may change
  member roles. Employees cannot elevate themselves. Demotion/deactivation of
  the last active admin is rejected. Other admins retain existing employee
  invitation/activation permissions, not owner-level promotion rights.
- `my_office_invitations` / `accept_office_invitation`: existing accounts accept
  user-bound invitations in-app. The inviter must still be an active office
  admin. Acceptance cannot reactivate revoked memberships. New accounts retain
  the existing email invitation/password setup flow and first membership setup.
- `invitation_user`: service-role-only lookup of an already confirmed Auth email;
  it is not an email directory exposed to Flutter. Existing users see invitations
  under Add Office; no new transactional email provider has been added for them.

RLS limits attendance/evidence and administrative member/profile reads to the
selected office **and** its actual active membership/role. Own global profile
access and the authorized office list are intentionally account-wide. The
preference is context, never an authorization credential. Direct client writes
to memberships, invitations, preferences, check-ins and evidence remain denied.
Every new security-definer function has an empty search path and explicit grants.

### Server Path Inventory

| Path | Office scope / authorization |
| --- | --- |
| `current_employee`, `company_employees` | Explicit organization RPCs, active selected membership; admin-only employee listing |
| `save_attendance_policy` | Explicit selected organization; locked active admin check |
| `manage-employees` | Auth JWT + explicit organization membership/role; scoped duplicate guards, activation RPC and bound invitations |
| `submit-attendance` | Auth JWT + target membership; organization-scoped idempotency lookup, lease, photo path, finalize and failure cleanup |
| `finalize_check_in` | Rechecks and locks target organization/membership; server timezone/window, evidence path and GPS constraints preserved |
| `attendance-evidence` | Active target-office admin; exact office filter and existing expiry/60-second signed URL |
| `complete_employee_invitation` | Service-only; verifies inviter, office, bound Auth user/email and acceptance state |
| `retention-cleanup`, `orphaned_media` | Existing cron secret/service-only authorization; bounded cross-office expiry/orphan maintenance, now including logos |

Original no-office RPC signatures are retained as single-active-office wrappers.
Old clients/requests with multiple possible offices fail closed with
`office_required`; they never silently choose another office. This compatibility
bridge is not permission to run old Edge Functions after adding memberships.

## Flutter State And Cache Boundaries

`Employee` retains its display employee number and adds Auth UUID, organization
ID and office name. `OfficeProvider` loads server offices/invitations, exposes
busy/errors, and serializes switch/create/accept/management operations. Permission
lists and selection are not persisted as local authorization. Offline switching
is unavailable, and Retry reloads the server state.

`AuthProvider` retains the session and global profile scope. Immutable Supabase
office backends capture Auth UUID, organization and a generation. Requests carry
explicit office IDs; pending replies/retries from an invalidated scope are
rejected rather than retargeted. An ambiguous switch requires server context
recovery before old office requests are allowed again.

Bootstrap keeps `ProfileProvider` account-scoped and recreates attendance,
history, admin, evidence-address cache, and navigation by office/role/epoch. An
opaque loading layer hides/blocks old content while context changes. Old routes,
including evidence and employee management, are disposed. Camera/file/GPS awaits
check mounted/scope state before submitting. An already accepted server request
can finish in its original office; it is never relabeled as another office.

The root MaterialApp/Navigator now has account lifetime. `OfficeScope` owns a
separate, disposable office navigator and the providers above. The switcher uses
the root navigator, so it remains open while office routes/caches are discarded.
The loading cover is inside the office navigator, not over the switcher. System
Back still pops office detail pages before exiting the application. The current
office navigator is resolved after dismissing the switcher for Manage Offices;
the sheet never retains a previous office's navigator.

Preview uses two isolated in-memory sample offices. Switching is demonstrable,
but uploads, creation, invitations and editing stay read-only. Legacy startup
without a company backend shows a non-interactive Local office header and keeps
the existing attendance implementation. No private files or keys are required
by the public configuration.

The switcher uses the existing Tabler catalog and design tokens, 104 dp circular
avatars, an active check, responsive wrapping, scroll/drag support, light/dark
themes and reduced-motion modal animation. Office management reuses the existing
employee invitation/activation screen; its layout is unchanged.

## Switcher Motion And Local Visibility Follow-Up

- Selection no longer dismisses the sheet. The selected avatar travels to the
  sheet center (420 ms), then returns to its grid position (520 ms). The adapted
  Buzz Bezier paths, easing, surface fade and scale run in sheet-local coordinates.
  Success/failure leaves the grid open, with explicit status feedback.
- Edit/Done morphs the active check into a remove bin over 220 ms. Its hit area
  remains 48 dp as the visible badge changes size. Selection/Edit/Manage use
  selection haptics, confirmed switching uses a light impact, and confirmed
  Remove uses a medium impact. Reduced motion skips the large flight and morph,
  including when that accessibility setting changes during animation.
- Remove means **hide on this device only**. It does not delete an organization,
  membership, check-in, photo, invitation or permission. Hidden IDs are stored
  under an Auth-UUID-specific SharedPreferences key. Preview visibility remains
  in memory and does not write production or persistent account data.
- Hiding the active office first requires a server-confirmed switch to a visible
  alternative. Failed switching never hides the active office; the last visible
  office cannot be removed. A hidden active office is always shown if server
  context later selects it. Manage Offices offers Restore for authorized hidden
  offices. Visibility preferences never grant access.
- Inter is bundled offline as `Office Inter` for this sheet only: 24 px / 600
  title, 16 px / 600 office labels. Home, History, Profile, colors and branding
  retain their existing typography/design. No packages were added. Adapted
  animation code and font licenses are attributed in
  [third-party-animations.md](third-party-animations.md) and Flutter's license list.
- Evidence receives a limited visual refresh: uncropped framed photo, loading
  and retry affordances, and separated time/location/device details. Existing
  timestamp, coordinate, accuracy, device and address strings remain unchanged.
  Photo retry requests fresh evidence without repeating cached address lookups.
  Attendance verification and backend behavior are unchanged.

Additional files: `lib/widgets/office/office_scope.dart`,
`lib/widgets/office/office_action_badge.dart`, `test/office_switcher_motion_test.dart`,
the bundled font/licenses and updated switcher/evidence light/dark goldens.
No SQL, Edge Functions, hosted settings or private implementation changed in this
follow-up. The original coordinated deployment gate below still applies.

### APK Update Note

After the initial feature commit, an ARM64 release APK was built separately at
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (about 20.5 MB).
`--split-per-abi --target-platform android-arm64 --build-number 7` gives Android
versionCode **2007**, matching the existing signing certificate. The earlier
universal APK had versionCode 6 while an older installed ARM64 build used 2006;
that downgrade can prevent an update. Future ARM64 builds must use build number
**8 or higher**, and retain the matching signing key. Do not uninstall or clear
phone data to work around an update failure without the owner's approval.
Installation on the user's phone has not been confirmed. No additional APK was
requested or rebuilt for the animation follow-up.

### File Map

- `lib/models/office_model.dart`: offices and bound invitation DTOs.
- `lib/models/employees_model.dart`: Auth/office identity and office-safe equality.
- `lib/services/company_backend.dart`: office capabilities and immutable scope hooks.
- `lib/services/supabase_company_backend.dart`: real office RPCs, scoped reads/writes,
  policy request deduplication, bounded RPC waits and safe context recovery.
- `lib/services/preview_company_backend.dart`: isolated in-memory office samples.
- `lib/providers/auth_provider.dart`: account/office scopes and server-confirmed selection.
- `lib/providers/office_provider.dart`: office lists, invitations, management, errors and concurrency.
- `lib/providers/admin_provider.dart`, `attendance_history_provider.dart`, and
  `attendance_provider.dart`: prevent disposed/late scope updates or uploads.
- `lib/bootstrap.dart`, `lib/app.dart`: separate provider lifetimes, route invalidation
  and an opaque switch-loading layer.
- `lib/screens/home/attendance_screen.dart`: new header and mounted/context checks
  after camera/file/GPS waits; the summaries/button/layout otherwise remain intact.
- `lib/widgets/office/office_selector_header.dart`, `office_switcher_sheet.dart`:
  reusable header/avatar and accessible native modal switcher.
- `lib/widgets/home/attendance_profile_header.dart`: removed after confirming Home
  was its only caller; Profile editing widgets remain.
- `lib/screens/office/manage_offices_screen.dart`, `office_roles_screen.dart`:
  office creation/name/logo, invitations, existing employee management and owner-only roles.
- `supabase/migrations/20261113160313_multi_office.sql`: all forward-only schema,
  backfill, authorization, RPC and Storage changes; older migrations are unchanged.
- `supabase/functions/_shared/server.ts`, `manage-employees/index.ts`,
  `submit-attendance/index.ts`, `attendance-evidence/index.ts`,
  `retention-cleanup/index.ts`: the scoped server paths listed above.
- `test/backend_schema_test.mjs`, `supabase/functions/_shared/handlers_test.ts`:
  real migration/RLS and mocked handler regression coverage.
- `test/office_provider_test.dart`, `office_bootstrap_test.dart`,
  `office_switcher_test.dart`, `supabase_office_backend_test.dart`, and
  `test/goldens/office_switcher_{light,dark}.png`: state, request and UI tests.
- `test/attendance_evidence_location_test.dart`, `employee_check_ins_sheet_test.dart`:
  preserve custom injected backend fixtures under the new scoping contract.
- `docs/backend-setup.md`, this file: updated model, safe rollout and handoff.

No Flutter dependencies, versions, private files or unrelated dirty files were changed.

## Safe Rollout Procedure

1. Back up the target database and inspect all live FK/function/policy
   dependencies; the migration was written against this repository's schema,
   not unknown manual production changes. Never use a database reset.
2. Restore a sanitized/disposable copy including at least one existing office,
   membership, profile, invitation, check-in, evidence row and submission lease.
3. Apply all pending forward migrations there using the installed CLI's local
   migration commands. The feature file is
   `20261113160313_multi_office.sql`; it uses a five-second lock timeout and
   60-second statement timeout. Contention/slow rewrites roll back the transaction
   rather than waiting indefinitely. Large membership tables may need a separately
   reviewed staged/backfilled expansion instead of this single pilot migration.
4. Review preserved counts, keys, employee codes, timezone/window values, owner
   assignments and all custom dependencies. Explicitly assign each legacy owner
   to an approved active admin UUID through project-owner tooling; do not derive
   it from email strings or user-editable metadata. An unexpected dependency must be
   resolved in an additional forward migration, not dropped with CASCADE.
5. Deploy the office-aware Edge Functions to the disposable project, including
   retention cleanup. Test PostgREST overload resolution and private Storage
   permissions with real employee/admin JWTs from two offices.
6. Test the new Flutter client against that project: invitation/password setup,
   login, create, switch, rename/logo, invite/accept existing user, role change,
   photo/GPS submission, history, evidence, window policy and revoked access.
7. For an approved hosted rollout, use a controlled maintenance window: apply
   the migration, deploy the matching functions, validate single-office legacy
   paths, then release the new client. Do not add multi-office memberships until
   all handlers and supported clients have been updated. Old single-office
   Edge code assumes one membership and is not safe to leave deployed.
8. Schedule the existing retention job. Roll forward to repair a failed rollout;
   do not remove memberships/attendance to recover an older client.

The initial implementation did not deploy or submit production attendance.
The separately approved hosted deployment is recorded below; no test attendance
or invitations were left in production.

## Validation

Recorded on 2026-11-13:

- Flutter analysis: no issues.
- Full Flutter suite: 131 tests passed, including the late session-refresh race
  and account-scoped profile update regression.
- Edge validation/handler suite: 17 tests passed; all five affected server/shared
  entrypoints also passed Deno type checking.
- Actual forward migrations/RLS passed in isolated PostgreSQL WASM with seeded
  legacy attendance/evidence and the multi-office assertions described below.
- Public `lib/main.dart` Flutter bundle compiled. Its compiler dependency file
  includes the office selector and neither ignored private entrypoint nor service.
- Both ignored private files retain their pre-feature SHA-256 hashes.
- New switcher goldens were visually inspected in light/dark mode. Narrow-screen,
  2x text and reduced-motion interactions pass without layout errors.

Not verified here: a full disposable Supabase deployment, actual SMTP/email
delivery, real-phone camera/GPS uploads, iOS behavior or production acceptance.
No live office access is granted until the approved migration/functions rollout.

Animation/local-visibility follow-up validation on 2026-11-13:

- Flutter analysis and final evidence-test analysis: no issues.
- Final full Flutter suite: **139 tests passed**. Coverage includes haptic calls,
  morph geometry/stable touch targets, avatar motion, retained root sheet state,
  nested Back, failure recovery, account-isolated hide/restore and photo retry.
- Public `lib/main.dart` bundle compiled with the Inter font and both licenses.
  Its compiler dependency file contains the office switcher and neither private
  Dart file. Both private-file SHA-256 hashes are unchanged.
- Switcher light/dark and Evidence goldens were inspected; existing Home,
  History, Login, Profile, Settings and navigation regressions remain passing.
- No additional APK, production deployment or device interaction was performed.
  Real haptic feel and motion on a physical phone still require owner testing.
  Database/Edge suites were not rerun for this UI-only follow-up; their earlier
  isolated results above remain historical, not a hosted acceptance claim.

```powershell
flutter analyze --no-pub
flutter test --no-pub
# Use the already pinned Edge dependencies; all handler HTTP endpoints are mocked.
deno test --allow-env --allow-read --allow-net=backend.example.invalid supabase/functions/_shared/validation_test.ts supabase/functions/_shared/handlers_test.ts
# Install a test tool only under ignored .dart_tool (not Flutter dependencies).
npm install --prefix .dart_tool/office-tools --no-save --ignore-scripts @electric-sql/pglite@0.3.14
$env:PGLITE_MODULE = (Join-Path $PWD '.dart_tool/office-tools/node_modules/@electric-sql/pglite')
node test/backend_schema_test.mjs
```

The database suite executes the actual migrations/RLS in isolated PostgreSQL
WASM, including seeded pre-migration data, dual memberships/roles, authorized
selection, atomic creation, owner-only promotion, last-admin protection,
invitation acceptance/retries, revocation, office-scoped leases and logo rules.
It supplies minimal Auth/Storage tables; it does **not** replace a full disposable
Supabase/Auth/PostgREST/Storage and real-phone camera/GPS acceptance test.

Flutter tests cover provider concurrency/failures, account/profile retention,
actual bootstrap cache/navigation replacement, real Supabase client requests
through mocked HTTP, late-response rejection, Preview isolation and light/dark
switcher goldens plus 320 dp/2x text/reduced-motion interaction checks. Existing
evidence fixtures explicitly retain their injected test backend when scoped;
their behavioral expectations were not weakened.

## Approved Live Rollout

Recorded on 2026-11-14, following the owner's explicit live-deployment approval
and confirmation of the existing PIPFA owner account. No unrelated Auth settings,
secrets, private SOAP files or application source were changed in this rollout.

### Backup And Rehearsal

- The live schema/FK inventory matched the expected single-office baseline. Dry
  run listed only `20261113160313_multi_office.sql`; Vault updates and seed data
  were excluded.
- The project listed no physical backups and PITR was disabled. Docker was not
  installed, so official portable PostgreSQL 17.12 client tools were used instead
  of installing a database service or changing system settings.
- A verified custom-format dump includes `public`, `auth`, `storage` and
  `supabase_migrations`. It is encrypted with Windows DPAPI CurrentUser, verified
  by decrypting in memory, and the plaintext dump was removed. It contains
  sensitive account/evidence data and must never enter Git.
- The durable recovery copy is outside Flutter/Git at
  `%USERPROFILE%/Attendance-backups/office-rollout-2026-11-14-05baeba/before-multi-office.dump.dpapi`.
  The same directory holds `previous-functions/`. Preserve this Windows account
  and profile to decrypt the backup; it is not a portable password-encrypted file.
  Storage object metadata is included, but Storage file contents are not backed
  up by pg_dump. Existing media files were not modified or deleted.
- The isolated PostgreSQL migration/RLS suite passed again, as did all 17 mocked
  Edge tests. A bounded transaction on the actual hosted database then rehearsed
  the exact migration, compared original row contents, tested office creation,
  multi-membership selection, admin/employee role separation, policy denial and
  evidence isolation, and ended with **ROLLBACK**. No rehearsal data persisted.
  This was not a separately deployed disposable full Supabase stack; real-device
  authenticated camera/GPS and invitation acceptance remain owner acceptance work.

### Deployment And Checks

- Applied the forward migration through CLI migration history with `--skip-vault`.
- Deployed matching functions via the API: `submit-attendance` v4,
  `manage-employees` v5, `attendance-evidence` v4 and `retention-cleanup` v4.
  All four report ACTIVE. Existing manual JWT/cron-secret authorization and
  gateway configuration were retained.
- Assigned the legacy PIPFA organization owner only to the explicitly confirmed
  original active admin account. A guarded transaction rejected ambiguous
  matches or an existing different owner. No other roles were changed.
- Preserved counts: 1 organization, 4 memberships, 4 profiles, 8 check-ins,
  8 evidence rows, 3 invitations and 0 submission leases. Added 4 active-office
  preferences and the private office-logo bucket. All public tables retain RLS.
- Read-only SQL under the admin identity returned PIPFA/admin, one authorized
  office, all 8 check-ins and 4 profiles. Live unauthenticated probes of all four
  Edge Functions and `my_offices` returned HTTP 401. No login session was minted,
  attendance uploaded or invitation email sent by these checks.
- Built-in security advisors reported no ERROR findings, but 20 warnings remain:
  18 authenticated SECURITY DEFINER API advisories, a pre-existing
  `rls_auto_enable` event-trigger exposure advisory, and disabled leaked-password
  protection. These are documented, not silently changed or presented as a clean
  comprehensive audit. The previously stopped multi-agent audit was not resumed.

### Delivery And Remaining Checks

- Feature and handoff updates are pushed on `codex/multi-office-switcher` to
  [draft PR #19](https://github.com/Umerjamshaid/Attendance-app/pull/19). Main was
  not merged or modified by this rollout.
- Final live-connected public ARM64 release APK:
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, about 20.9 MB,
  versionName `1.1.0`, versionCode **2009** (`--build-number 9`). This replaces
  the intermediate preview-only versionCode 2008 at the same output path.
  It includes only the public Supabase URL/publishable key, not a server secret
  or the ignored private SOAP implementation.
- APK signature and 16 KiB alignment verification pass. Existing test signing
  certificate is retained to allow updates; this is a release-mode pilot APK,
  not a Play Store production-signing setup. SHA-256:
  `5AC6AB1D45F44B4EABBBE5D2B028FD8C1A4485858F84186C1919CD61F2806926`.
  Future ARM64 builds should use build number **10 or higher**.
- Compiler dependencies include the office switcher/Supabase backend and exclude
  both private Dart files. Their pre-feature hashes remain unchanged. The latest
  application-source validation is still 139 passing Flutter tests and clean
  analysis; this delivery only adds documentation after that source validation.
- The owner postponed physical-phone testing. No connected ADB device was found;
  actual animation/haptic feel, camera/GPS upload, login/invite acceptance and iOS
  remain unverified. Do not uninstall or clear phone data to test an update.
- Shutdown was requested for 28 historical sub-agent IDs recovered from this
  chat; every close call returned `not found`. No new agents were spawned. This
  does not claim that old UI history entries were deleted or remotely stopped.

Next handoff: complete the owner's phone acceptance with the live-connected APK,
review the documented advisor warnings before wider distribution, and preserve
the encrypted recovery copy. Keep ignored private code, backups and pre-existing
unrelated edits out of commits. Do not restart the stopped security-audit workflow.

References: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[Buzz switcher](https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher.dart).
