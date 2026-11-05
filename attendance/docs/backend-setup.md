# Company Pilot Setup

## Visitor Preview Versus Company Access

`flutter run` opens the public login. **Explore demo** uses only in-memory sample
data. It never creates a Supabase session, reads company records, captures a photo,
or sends a location. No shared demo account or production database policies are
needed. Profile edits and attendance submission are unavailable in the preview.

Real users need an administrator's invitation. Keep public sign-up disabled. Do
not give GitHub visitors company credentials; invite approved trial users to a
separate test organization/project with synthetic data.

## Architecture

Provider remains the state layer. `CompanyBackend` is injected through bootstrap.
The public entrypoint uses Supabase services or an unavailable-sign-in backend
with a working demo option. Legacy startup defaults are unchanged. The public app
does not import or require any owner-only attendance implementation.

Auth UUIDs identify users. Employee numbers are display/company identifiers, not
passwords. Only the database controls membership, roles, active access, and the
attendance window. Client roles and user-editable auth metadata never authorize
an operation. A random installation UUID is context, not proof of identity.

## Deploy To Your Own Project

Requires Node/npm, Supabase CLI, an owned Supabase project, and administrative
authentication. Do not paste credentials into chats, GitHub, or source files.

```powershell
npx supabase login
npx supabase db push --remote=YOUR_PROJECT_REF --dry-run
npx supabase db push --remote=YOUR_PROJECT_REF --skip-vault --yes
npx supabase config diff --remote=YOUR_PROJECT_REF
npx supabase config push --remote=YOUR_PROJECT_REF --yes
npx supabase functions deploy --remote=YOUR_PROJECT_REF --use-api --yes
```

With CLI v3, an unlinked project can be targeted explicitly using
`--remote=YOUR_PROJECT_REF` for `db push`, `config diff`, `config push`, and
`functions deploy`. Use `--yes` only after reviewing the corresponding dry run
or diff. Function deployment can use `--use-api` when Docker is not installed.

Review the migration before applying it. It creates new company tables, explicit
grants/RLS, and two private Storage buckets. It does not reset existing data.

In Auth settings, disable new public sign-ups, set minimum password length to 12,
enable email confirmations and secure email changes, and allow the exact redirect
`workcheck://auth/callback`. `supabase/config.toml` documents these settings;
deploying functions or database migrations does **not** automatically apply Auth
settings. Configure production SMTP and test delivery before inviting employees.

The callback is configured for Android and iOS. Test invite/recovery links with
the app installed, including cold starts. A custom scheme is suitable for the
pilot; verified HTTPS app/universal links require an owned domain before a broad
commercial release. iOS builds must be verified on macOS.

Functions manually verify user JWTs using Auth before any privileged access.
`verify_jwt = false` only disables the platform's legacy JWT gateway check; it
does not disable the handlers' authentication. Keep the server credential inside
Supabase Edge Functions only. The SDK uses Supabase's supplied server environment
or an explicitly configured `SUPABASE_SECRET_KEY`, never a Flutter value.

## First Company And Admin

Create/invite the owner from the Supabase Auth Dashboard, then obtain that user's
UUID. Run this template in SQL Editor, replacing values deliberately:

```sql
begin;
with company as (
  insert into public.organizations(name) values ('Your company') returning id
), owner as (
  insert into public.memberships(user_id, organization_id, employee_code, role, department)
  select 'OWNER_AUTH_UUID'::uuid, id, 'ADMIN001', 'admin', 'Administration'
  from company returning user_id
)
insert into public.profiles(user_id, name) select user_id, 'Owner name' from owner;
commit;
```

Set a password through invitation/recovery. Admin invitations inside the app
create employees only, never administrators. Additional admins must be explicitly
provisioned by the project owner through administrative tooling. One account
belongs to one company in this pilot. Deactivation immediately blocks new data
access even with an existing JWT; it does not delete historical check-ins.

The organization starts in `Asia/Karachi` with the existing 7 AM–1 PM schedule.
The admin can select Scheduled or Always open in the existing window sheet.
The server is authoritative; device-clock changes cannot open a closed window.

## Configure The Public App

Use your own project URL and **publishable** key:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

These values identify a public client; they are not a security boundary. Never
put a secret/service-role key in Flutter, even in an ignored `.env` file. For a
store build, pass the same defines to `flutter build appbundle --release` after
configuring a real signing key and application identity.

## Evidence And Retention

Employees can read their own check-in metadata, not photos, precise GPS, or
installation identifiers. Only active same-company admins can request evidence.
Photos use private Storage and signed links lasting 60 seconds. Already-issued
links can remain usable until expiry after logout/deactivation.

Evidence expires after 90 days. RLS and the evidence handler deny expired records
even if cleanup is delayed. The `retention-cleanup` function deletes expired
photos through the Storage API before deleting GPS/device evidence. It preserves
minimal check-in history and retries safely after failures. It also cleans up
unreferenced uploads older than 24 hours. Never delete Storage objects using raw
SQL: that leaves the actual files behind.

Create a strong random `CRON_SECRET` in a local secure environment and set it as
an Edge Function secret. Store the same value in Supabase Vault under
`workcheck_cron_secret`; store the function base URL under `workcheck_functions_url`
(for example `https://YOUR_PROJECT.supabase.co/functions/v1`). Enable Cron and
pg_net, then run the following scheduling SQL. Do not commit the actual secret:

```sql
select cron.schedule('workcheck-evidence-retention', '15 * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='workcheck_functions_url') || '/retention-cleanup',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' ||
      (select decrypted_secret from vault.decrypted_secrets where name='workcheck_cron_secret')),
    body := '{}'::jsonb
  );
$$);
```

Check the response status and function logs after a manual test. Review cleanup
failures regularly; do not claim automated retention is operational until this
job is installed and verified. Supabase-managed backups have separate retention
and must be addressed in the company's deployment/privacy policy.

## Validation And Release Gates

```powershell
flutter analyze
flutter test
npx deno check supabase/functions/submit-attendance/index.ts supabase/functions/manage-employees/index.ts supabase/functions/attendance-evidence/index.ts supabase/functions/retention-cleanup/index.ts
npx deno test supabase/functions/_shared/validation_test.ts
```

The Node security test executes the real migration in isolated PostgreSQL using
`@electric-sql/pglite`. Install that package in a temporary tools directory, set
`PGLITE_MODULE` to its absolute module directory, and run
`node test/backend_schema_test.mjs`. It tests tenant isolation, evidence denial,
role restrictions, idempotency, deactivation, and expiry without live data.

Before onboarding: verify real email delivery, invite acceptance, password reset,
refresh/logout, disabled employees, GPS/camera failures, closed windows, duplicate
requests, admin evidence access, retention cleanup, and both public/private build
compatibility. Current Android release configuration still uses debug signing;
it is **not** a commercial distribution configuration. Do not sell this as a
payroll, absence-calculation, biometric-verification, or tamper-proof system.

Logs intentionally contain stable error codes, not photos, coordinates, passwords,
tokens, or signed URLs. Push delivery, billing, badges, offline uploads, and
multi-company self-service onboarding are not implemented in this pilot.

Security Advisor will flag the authenticated SECURITY DEFINER functions. These
are intentional, have fixed search paths and explicit caller/role checks, and
are covered by access-control tests. Review them rather than blanket-granting or
disabling RLS. Supabase may also contain its own pre-existing RLS event helper.
Leaked-password protection and production SMTP are separate deployment settings;
verify their availability/configuration before a commercial launch.
