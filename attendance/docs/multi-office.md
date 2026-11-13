# Multi-Office Handoff

## Scope And Status

Office is the UI name for `public.organizations`. Provider and `CompanyBackend`
remain the application architecture. The Home profile header is replaced by an
office selector; Profile editing, Home/History summaries, the floating dock,
camera/GPS verification, and the private startup/service are not redesigned.
Broader Buzz/onboarding work remains on hold. No sub-agents were used.

This change is local source plus a forward-only migration. **Nothing here has
been deployed to a hosted Supabase database.** Do not distribute this client
against the old schema/functions; complete the coordinated rollout below first.
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

Preview uses two isolated in-memory sample offices. Switching is demonstrable,
but uploads, creation, invitations and editing stay read-only. Legacy startup
without a company backend shows a non-interactive Local office header and keeps
the existing attendance implementation. No private files or keys are required
by the public configuration.

The switcher uses the existing Tabler catalog and design tokens, 104 dp circular
avatars, an active check, responsive wrapping, scroll/drag support, light/dark
themes and reduced-motion modal animation. Office management reuses the existing
employee invitation/activation screen; its layout is unchanged.

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

No hosted deployment, real invitations, production writes, APK build, or
production attendance submission is part of this implementation run.

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

Next handoff: keep the production deployment gate closed until the disposable
full-stack and device tests above pass. Keep the ignored private startup/service
and pre-existing unrelated work out of this feature commit. Do not resume the
previously stopped security-audit workflow as part of this feature.

References: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[Buzz switcher](https://github.com/block/buzz/blob/main/mobile/lib/features/channels/channels_page/community_switcher.dart).
