# Admin Check-in Activity

The bell next to Manage employees in Admin shows the latest 30 confirmed
check-ins for the selected office.
Each row contains a name (or the employee code) and the time the server received
the check-in, displayed in the office's time zone. Opening the screen or
pulling down refreshes the list.

## Backend

- `20261119090000_office_check_in_activity.sql` adds a bounded,
  read-only RPC and an index on existing check-ins. Only an active admin
  of the selected office can call the RPC successfully. Caller-level RLS
  also applies to its reads.
- The RPC never reads or returns evidence photos, GPS, or device identifiers.
  It does not add a trigger or change attendance submission, retries, or
  policies. Repeating the same submission request still returns the same
  check-in ID and therefore appears once.
- The screen drops old rows when the account, office, or role changes. It
  does not cache the feed on disk. The preview backend only contains sample
  rows; employee preview accounts do not gain an Admin tab.

## Test Before Deployment

1. Apply the new migration to a disposable local or staging database that
   already has the preceding migrations. Do not run against the pilot project
   before approval. See [backend setup](backend-setup.md).
2. Run `node test/backend_schema_test.mjs` with the existing local PGlite
   setup. Run `flutter test test/admin_check_in_activity_test.dart`.
3. In a build configured for staging, sign in as an admin and open
   **Admin > Check-in activity** (the bell). Submit a check-in as a test
   employee, pull to refresh, and verify that the row appears once.
4. Switch offices and refresh. Verify the new office's own activity. An
   employee, a demoted admin, and a deactivated admin cannot fetch this feed.

This follows Buzz's separation of in-app activity from push delivery. BunPod's
episode alert switch is commented out in the checked-out source. Attendance
does not request notification permission from this feed, and has no push,
read/unread tracking, or schedules in this release.
