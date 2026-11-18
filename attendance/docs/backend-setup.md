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

Review every pending migration before applying it. The pilot created company
tables, explicit grants/RLS, and two private Storage buckets. The multi-office
expansion adds an office-logo bucket and changes membership keys without resetting
existing data. Follow [the coordinated rollout](multi-office.md) before applying
that expansion or distributing its client; do not deploy old functions with it.

In Auth settings, disable new public sign-ups, set minimum password length to 12,
enable email confirmations and secure email changes, and allow the exact redirect
`workcheck://auth/callback`. `supabase/config.toml` documents these settings;
deploying functions or database migrations does **not** automatically apply Auth
settings. Configure production SMTP and test delivery before inviting employees.

The callback is configured for Android and iOS. Test invite/recovery links with
the app installed, including cold starts. A custom scheme is suitable for the
pilot; verified HTTPS app/universal links require an owned domain before a broad
commercial release. iOS builds must be verified on macOS.

To enable **Use email code** in the hosted app, apply the contents of
`supabase/templates/invite.html` and `supabase/templates/recovery.html` to the
hosted project's **Invite user** and **Reset password** email templates. Retain
both `{{ .ConfirmationURL }}` and `{{ .Token }}`. `config.toml` applies these
templates to local development only. See the
[Supabase email template guide](https://supabase.com/docs/guides/auth/auth-email-templates).
Do not change the redirect scheme when removing app branding: it is part of
existing signed-in flows and links already sent.

### Admin-shared office codes

Apply the `office_invite_codes` migration before distributing a client with
**Office code** invitations. No Edge Function or email-template change is
required for this method. In **Employees > Invite employee**, choose **Office
code**, enter the person's verified Attendance email and employee details,
then reveal and copy the code. Generating another code for the same account
and office replaces the previous one.

The employee can use **Offices > Join with an office code** while signed in or
**Use office code** on the sign-in screen with their existing credentials.
Codes grant employee membership only, are valid for 24 hours, and are tied to
the invited account. An inviter must still be an active office administrator
when the code is used. First-time accounts still use email verification and
password setup; the manually shared code does not replace account verification
or password recovery.

The hosted pilot applied this migration on 2026-11-18. Other deployments still
need to apply it before using the office-code option.

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
create employees only, never administrators. With the multi-office migration,
office owners can manage office-specific roles, and existing active admins can
create another office. An account may have multiple authorized memberships;
existing accounts accept additional invitations under Add Office. See
[Multi-Office Handoff](multi-office.md) for owner backfill review and access rules.
Deactivation immediately blocks new data
access even with an existing JWT; it does not delete historical check-ins.

Invitations do not contain a generated password. With the app installed, open
the invitation on that phone and choose a password of at least 12 characters.
If an email browser does not open the app, use **Use email code** and select
**Employee invitation** or **Password reset**, matching the newest email. A
code and link in the same email are single-use alternatives. If an invitation
was already used, expired, or opened before installation, use **Forgot
password?** in the app to request a fresh email. Open a recovery link on the
same phone that requested it or use its code. Do not share passwords, codes,
or links. Visitors using **Explore demo** do not need an account or password.

For real-device verification, open an invite with the app closed and a reset
link with the reset form still open. Restart before saving and confirm it
returns to **Set password**. Save the password and check that navigation
advances without reopening the app. Also test an expired link and one-time
code. If corporate mail scanning consumes links in advance, confirm SMTP/link
tracking behavior or consider a code-only template for that rollout.

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

Profile avatars and cover photos accept JPEG/JPG, PNG, GIF (including animation),
WebP, and BMP. The app permits avatars and non-GIF banners up to 5 MB
(5,242,880 bytes), and GIF banners up to 10 MB (10,485,760 bytes). The shared
private `profile-media` bucket has a 10 MB ceiling. The forward migration
`20261115222312_profile_media_kind_limits.sql` also enforces per-kind limits on
Storage's final measured metadata: 5 MB normally, or 10 MB for `banner-*.gif`
objects reported as `image/gif`. It checks both size fields, including writes
performed by Storage's privileged completion path; it does not trust custom
user metadata. This is MIME/size validation, not server-side image-byte decoding.
Apply `20261115224246_profile_media_upload_probe_compatibility.sql` too: it limits
the hook to final metadata containing measured `size`, since authorization
probes can report a multipart request length including non-file overhead.
The app separately verifies file signatures. The allowed MIME types and
private access policies are unchanged. Attendance evidence and office logos
retain their separate 2 MB JPEG/PNG restrictions. Older APKs still enforce their
bundled limit and must be updated to use the larger allowance.

The narrow `profile_media_size_guard` trigger is a custom Storage-schema hook.
Recheck it against Storage's upload/probe/completion contract during upgrades;
do not replace it with an RLS-only size check, because some service versions
complete uploads with elevated privileges. It changes no existing objects.
If an incompatible Storage upgrade requires rollback, remove that trigger and
its `public.enforce_profile_media_size()` function through a reviewed forward
migration. Doing so restores the shared 10 MB ceiling, not the per-kind guard.

Office-review fixes are forward-only migrations. The new `update_office_fields`
RPC preserves fields omitted by an action; legacy clients retain the original
RPC. Existing owners cannot self-demote, and reissued pending invitations record
the current inviter without rewriting accepted-invitation provenance. Deploy the
new migration before distributing the updated client that calls this RPC.

```powershell
flutter analyze
flutter test
npx deno check supabase/functions/submit-attendance/index.ts supabase/functions/manage-employees/index.ts supabase/functions/attendance-evidence/index.ts supabase/functions/retention-cleanup/index.ts
npx deno test --allow-env --allow-read=supabase/functions supabase/functions/_shared
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
