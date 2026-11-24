# Changelog

## 1.1.1

### Changed

- The navigation dock respects Android system buttons and fits shorter windows.
- Attendance opens offline with local features available and company actions locked.
- About can save the bundled CV without a connection. The download arrow morphs
  into a checkmark after the PDF is saved.
- When an invitation hits the email sending limit, a sheet explains the failure
  and keeps the employee details ready for a later retry.
- Recent invite activity shows confirmed sends from this device with rolling
  digits, a seconds dial, and a rolling-hour progress arc. It does not predict
  the shared email quota.
- The attendance gauge pointer tracks the actual percentage along the arc.
- Avatar and office logo thumbnails decode at the displayed size and screen
  density without resizing cached GIF files or reducing evidence photo quality.
- The Admin inbox has All and Unread filters.
- What's New uses `gpt_markdown` for the installed GitHub release when available,
  with cached and bundled notes for offline use.
- Successful check-ins can show a queued, swipe-to-dismiss in-app banner.
- Home and check-in evidence use smaller, aligned location icons.
- Office Roles groups members by role and confirms changes inside the editor.
- Admin check-in activity groups today's and earlier events, shows an unread
  dot, and saves read status on the device separately for each account and office.
  While the app is open, private Supabase Realtime signals refresh the inbox
  and show new check-ins from other employees as banners.
- Employee Management now separates current and removed staff, keeps search
  in the toolbar, and opens employee actions in a sheet. Remove revokes office
  access without deleting check-ins; returning employees can redeem a fresh
  office code.
- Office Switch opens using the current office list, refreshes stale data after
  entry, and loads rows as they come into view. Existing office checks,
  selection motion, and haptics are unchanged.
- Graphite dark mode has more visible separators in Settings and Appearance.
- Sign out, Help Centre, and About now open as bottom sheets from both Profile
  and Settings. Help Centre can open email or GitHub, or copy the email address.
- The handwritten maker credit opens a contact sheet. About shows the
  installed version and build number.
- Settings > What's new lists these changes. Returning users see the
  highlights once after installing an update, when Home is ready.
