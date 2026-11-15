# P Attendance

A Flutter attendance app for teams: photo check-ins with location evidence, office-specific attendance history, and practical admin tools.

What started as a UI project now includes a working Supabase backend, authenticated accounts, and multi-office access. A read-only demo lets visitors explore the app without an account or access to company data.

<p align="center">
  <img src="attendance/screenshots/banner.png" width="100%" alt="P Attendance project banner">
</p>

## What You Can Do

- **Check in with evidence:** capture a photo and verified GPS location, with a timestamp and device information.
- **Switch offices:** move between authorized offices, each with its own employees, attendance settings, history, and permissions.
- **Review attendance:** see today's status, monthly progress, streaks, and the History overview.
- **Manage your team:** review employees and their profile photos, open check-in logs in a bottom sheet, and inspect photo/GPS evidence with an address when available.
- **Manage access:** invite employees and use office-specific administrative controls. Role changes remain server-authorized.
- **Make it yours:** edit your profile, change appearance, and use animated GIFs or other supported images for your avatar and banner, up to 5 MB.

## Interface

The refreshed interface uses soft gray surfaces, teal accents, bundled Inter typography, and consistent Tabler icons. The centered bottom navigation supports both taps and synchronized swipes, with selected animated icons, spring-based sheets, haptic feedback, and reduced-motion support.

Forms keep validation messages beside their fields, while short action feedback appears in a shared toast. Profile images are cached per signed-in viewer, and attendance evidence keeps its separate private loading path.

**Updated mockups and a short demo video are coming soon.** The gallery below shows an earlier design, not the current interface.

<details>
<summary>Earlier interface mockups</summary>

<table>
  <tr>
    <td><img src="attendance/screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%201.png" width="240" alt="Earlier attendance screen"></td>
    <td><img src="attendance/screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%202.png" width="240" alt="Earlier history screen"></td>
    <td><img src="attendance/screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%203.png" width="240" alt="Earlier admin dashboard"></td>
  </tr>
  <tr>
    <td><img src="attendance/screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%204.png" width="240" alt="Earlier profile screen"></td>
    <td><img src="attendance/screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%205.png" width="240" alt="Earlier settings screen"></td>
    <td><img src="attendance/screenshots/Samsung%20Galaxy%20S21%20Ultra%20Screenshot%206.png" width="240" alt="Earlier privacy screen"></td>
  </tr>
</table>

</details>

## Try The Demo

Use a Flutter SDK compatible with Dart `^3.11.4`, plus an Android device or emulator.

```sh
git clone https://github.com/Umerjamshaid/Attendance-app.git
cd Attendance-app/attendance
flutter pub get
flutter run
```

Choose **Explore demo** on the sign-in screen. It uses sample data, needs no account, and does not request camera/location access or upload anything. Demo edits and submissions are disabled.

Live company access is invitation-only. Contact the project owner for an approved trial, or follow the [backend setup guide](attendance/docs/backend-setup.md) to use your own Supabase project. Never post passwords, access tokens, or employee evidence in issues.

## Built With

| Area | Implementation |
| --- | --- |
| Application | Flutter and Dart |
| State and services | Provider and the existing CompanyBackend interface |
| Backend | Supabase Auth, Postgres, private Storage, and Edge Functions |
| Capture and location | image_picker, Geolocator, and reverse geocoding |
| Interface | Bundled Inter, Tabler icons, and selected animated Lucide icons |
| Profile media | cached_network_image and flutter_cache_manager |

## Development

Run these commands from `attendance/`:

```sh
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64
```

Without backend configuration, the build opens the demo-capable sign-in flow. Live builds require the configuration described in the setup guide.

Android release builds and automated tests are verified locally. Physical-device acceptance and iOS verification remain ongoing; this is an actively developed showcase and pilot, not a claim of production certification.

## Design Inspiration

The interface is heavily inspired by [Block Buzz](https://github.com/block/buzz/tree/main/mobile), especially its office/community switching, bottom sheets, typography, navigation, and action feedback. Those ideas are adapted to Attendance's workflows and Provider architecture, rather than bringing across Buzz's backend or identity system.

See [design and animation attribution](attendance/docs/third-party-animations.md) for upstream references, modifications, and bundled license notices.

Built by **Umer Jamshaid**.
