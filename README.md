# Reel Reminder

Current version: **0.0.3+3**. See [V0_0_3_REPORT.md](V0_0_3_REPORT.md)
for this release's changes and validation limits.

An Android-first Flutter MVP: share a link into the app, save it immediately,
and find it later by date. Material 3, email/password Firebase authentication,
Firestore, event/state BLoCs, Analytics, and Crashlytics. No authenticated scraping, AI, billing,
or downloaded media.

## Run

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run
```

The installed SDK used during development is Flutter 3.44.4 / Dart 3.12.2.
The Android application ID is currently `com.example.reel_reminder`.
Before store release, choose a permanent ID, register that ID in Firebase,
and configure release signing; the starter project currently uses debug signing.

## Firebase setup

Existing FlutterFire-generated `lib/firebase_options.dart`,
`android/app/google-services.json`, and `firebase.json` reference project
`fir-284f8`. They are client configuration, not service-account credentials.
No new credentials were invented. Enable Email/Password in Firebase Authentication,
create the default Firestore database, and enable Analytics/Crashlytics in that project.
Those console settings and live service availability have not been verified.

To configure a project you own, or refresh platform setup after adding Crashlytics:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=fir-284f8 --platforms=android,ios
```

FlutterFire generates/updates `lib/firebase_options.dart`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`,
`firebase.json`, and applicable Gradle/Xcode configuration. On macOS, rerun
FlutterFire and CocoaPods for iOS Crashlytics. Android Crashlytics Gradle wiring is
included here. Firebase setup reference: https://firebase.google.com/docs/flutter/setup

Deploy the reviewed owner-only rules before using real accounts:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project=fir-284f8
```

This command modifies your remote project. Rules have been supplied locally;
deployment is a separate operational step.

## Structure

```text
lib/
  core/services/       native share adapter, privacy-conscious telemetry
  core/utils/          URL parsing, platform detection, dates, duplicates
  features/auth/       Firebase repository, AuthBloc, email/password form
  features/saved_items/ model, Firestore repository, SavedItemsBloc, timeline/cards
  features/profile/    account, plan, theme
  main.dart            Firebase bootstrap and dependency composition
```

Only `AuthBloc` and `SavedItemsBloc` manage application state. Small tab/form/theme
interactions use widget state. `provider` is a transitive implementation dependency
of `flutter_bloc`; the app does not use Provider for state management.

## Share flow and reliability

1. Android registers `ACTION_SEND`, `CATEGORY_DEFAULT`, and `text/plain`.
2. `MainActivity` handles both initial launch and `onNewIntent` (`singleTop`).
3. The payload receives a UUID and is committed to an app-private native inbox.
4. On sign-in/resume, `ShareService` claims unowned shares for that account.
5. `SavedItemsBloc` extracts the first valid HTTP(S) URL and detects its platform.
6. Firestore writes to the UUID document. A local snapshot provides immediate UI
   feedback; its cloud-upload icon indicates pending server confirmation.
7. The native inbox is acknowledged only after server confirmation. A failed
   write can be retried with refresh or on resume, including after process death.

Firestore disk persistence is enabled. The inbox is account-bound after claim,
so a failed share cannot silently migrate to a different account on logout.
Native backup is disabled. Plain text without a URL shows a useful error and is
discarded; payloads over 20,000 characters are rejected visibly.
The app does not fetch metadata; cards fall back to shared text and domain.

Rapid repeated normalized URLs are suppressed for eight seconds during intake.
The stable inbox UUID also makes retries of the same share idempotent. A later
intent may intentionally save the same URL again.

Items load in batches of 100. **Load older finds** expands the loaded history.
Search and date filters apply to loaded items; this scope is shown in the UI.
Weeks start Monday. Calendar constructors provide local midnight boundaries
without assuming all days are 24 hours. A local-midnight timer and resume refresh
handle date changes without rebuilding the library every minute.
Theme selection lasts for the current app session; the default follows the device.

## Data and security

```text
users/{uid}
  plan: free | pro
users/{uid}/saved_items/{uuid}
  userId, url, sharedText?, title?, thumbnailUrl?, platform
  createdAt, updatedAt: server timestamps
  clientCreatedAt: device save timestamp (stable date history while offline)
  isFavorite: boolean
```

`SavedItem.createdAt` represents the device save time for timeline use; persisted
server timestamps remain available for server bookkeeping. Clock accuracy depends
on the device. Rules validate keys/types, enforce ownership, restrict updates to
favorite/update time, and prevent clients granting themselves Pro. A trusted future
backend can manage plans. No plan restrictions or billing are implemented.

Analytics sends event names only, never URLs, queries, email, or shared content.
Crash reporting records operation/type and stack traces without raw exception
messages. Verify a controlled crash in a test build before release, following
https://firebase.google.com/docs/crashlytics/flutter/get-started.

## Rules tests (local emulator only)

Requires Node, Firebase CLI, and a Java version supported by the Firebase emulator.
Firebase CLI 15 requires Java 21 or newer. If your shell defaults to an older JDK,
point `JAVA_HOME` and the first Java entry on `PATH` to JDK 21 for this command.

```powershell
Push-Location tools/rules_tests
npm install
Pop-Location
firebase emulators:exec --only firestore --project demo-reel-reminder "node --test tools/rules_tests/rules.test.mjs"
```

The suite checks owner CRUD, cross-account/anonymous denial, schema validation,
timestamp/ownership immutability, and prevention of client Pro escalation.

## Device acceptance checklist

Use a configured Firebase test project and two test accounts. A successful APK
build/unit test is not evidence that these device scenarios have passed.

- Register, force-stop/reopen (session restored), sign out, and sign back in.
- From YouTube and Instagram, Share → Reel Reminder; verify platform and Today.
- Share browser text containing a URL with surrounding prose.
- Exercise both cold launch and an already running/background app.
- Share while signed out, close/reopen, sign in, and verify the queued link.
- Share in airplane mode; verify the pending icon, restart, reconnect, and verify sync.
- Send a rapid duplicate, then repeat after eight seconds; expect one then two items.
- Seed yesterday/week/month items; verify grouping, filters, and local midnight boundaries.
- Search by text, URL, and platform; load older items and search again.
- Open original, copy, reshare, favorite, cancel deletion, and confirm deletion.
- Verify a second account sees none of the first account's items.
- Verify server-rejected writes display an error and the share retries after access is fixed.

Useful Android intake smoke command (replace the URL as needed):

```powershell
adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT https://youtu.be/example -n com.example.reel_reminder/.MainActivity
```

Actual external-app Share Sheet selection still requires a device check.
For a repeatable signed-out native smoke test on a disposable emulator:

```powershell
./tools/native_share_smoke.ps1 -Serial emulator-5580
```

This sends synthetic links and verifies registration, cold/warm intake, and the
native inbox after force-stop. It intentionally leaves synthetic pending shares
in that test installation; do not use it on a personal installation.

iOS has Firebase options and shared Dart architecture, but an iOS Share Extension
and App Group inbox are deliberately deferred; Android is the supported V1 target.
#   r e e l _ r e m i n d e r  
 
