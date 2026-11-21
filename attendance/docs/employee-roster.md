# Employee roster

- **Current** includes active and paused employees. Pause and restore are
  reversible access changes. **Removed** is separate and requires a new invite
  to regain access. Search matches names, employee numbers, departments, and
  emails in the selected list without making a request on each keystroke.
- **Remove from office** stops access to that office without deleting the
  account, membership key, profile, or past check-ins. Other offices are not
  affected. Evidence still follows its existing retention policy. Admins
  cannot be removed directly; the office owner manages roles separately.
- **Reinvite** creates a single-use, 24-hour code for the employee's existing
  account. Share it privately. Reissuing replaces the previous code. The
  employee enters it in **Use office code** at sign-in or in Manage Offices.
  They must be able to sign in to their verified account. This action does
  not send email or reactivate them until they redeem the code.

## Deployment and verification

Apply `20261121093611_employee_roster_removal.sql` to staging before
distributing a build with the new roster. It introduces an office-scoped
removal timestamp and two authenticated RPCs. Existing clients continue to
read the roster; a removed membership cannot be reactivated by the old
pause/restore API. Existing invitation and sign-in flows use the same code
redemption RPC.

Run `node test/backend_schema_test.mjs` with the documented local PGlite
setup and `flutter test test/search_tags_test.dart test/office_code_screen_test.dart`.
Verify an actual invite on staging with an employee in two offices, before
rolling out to any live office.

The pilot project now has this migration and the Admin check-in activity
migration. The local migration suite verified actual removal and redemption.
Post-deployment checks on the pilot were read-only: they verified the removal
constraint, the RPC grants, and unchanged record counts. No live employee
was removed or reinvited as part of deployment.
