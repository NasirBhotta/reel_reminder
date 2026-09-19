# Version 0.0.2

## Existing implementation and scope

The repository already contained email/password authentication, two event/state
BLoCs, an account-bound native Android share inbox, persistent Firestore writes,
timeline/search/date filters, item actions, themes, Analytics and Crashlytics.
These were retained. No dependencies or major product features were added.
Although the request calls the baseline 0.0.1, its actual pubspec/profile version
was 0.1.0. The new version is 0.0.2+2, retaining an increasing Android build number.

## Fixes

- Android distinguishes consumed/restored share intents, ignores stale Recents
  intents, clears consumed payloads, reports unsupported/empty payloads, and
  accepts a text ClipData fallback. Native inbox persistence remains in place.
- A share arriving during an inbox read triggers another read. Per-session handled
  IDs prevent duplicate queued events and repeated save feedback; eventual write
  failures permit retry. The existing eight-second normalized URL guard remains
  account-scoped through the per-user BLoC and tolerates out-of-order timestamps.
  Intentional later saves remain possible.
- URL validation rejects invalid host labels, ports, malformed escapes, backslashes
  and invalid numeric IPv4 addresses. Balanced brackets survive prose extraction.
  A malformed candidate does not hide a later valid HTTP(S) link. Host case is
  normalized without dropping query parameters. Existing boundary-aware detection
  covers TikTok, Instagram, Facebook/fb.watch, YouTube/youtu.be, X/Twitter,
  Reddit/redd.it and Website fallback.
- Write feedback requires a pending local snapshot or server acknowledgment;
  a stale initial snapshot cannot falsely report a newly requested change queued.
  Inbox acknowledgment failures are distinguished from failed Firestore writes.
  Repeated overlapping favorite/delete requests for the same item are guarded.
- Local Today/Yesterday/This Week/This Month/Older grouping is complete.
  Local-midnight/resume refresh replaces minute-by-minute timeline rebuilding.
- Search collapses whitespace, ignores case and supports Twitter as an X alias.
  It continues to operate on loaded items only.
- Opening validates the HTTP(S) link and attempts a browser view if an external
  handler fails. Open failures offer copying into a browser. Short lists remain
  pull-refreshable; card platform labels truncate safely; malformed stored URLs
  no longer crash card titles. Delete confirmation is retained.
- Profile holds its plan stream across rebuilds. Version display is updated.
- Analytics uses `share_received`; item/action/filter/search events contain no
  user content. Uncaught errors are marked fatal in Crashlytics; expected invalid
  shares remain validation messages rather than crash reports.

## Rules

Final rules are in `firestore.rules`. Existing authenticated UID/path checks,
strict schema validation, server timestamps and favorite-only updates remain.
Updates now also explicitly require existing ownership to match the path and
prohibit ownership changes. Anonymous and cross-account access remain denied.
Rules were reviewed locally, not deployed or exercised against an emulator.

## Files changed

- `pubspec.yaml`
- `android/app/src/main/kotlin/com/example/reel_reminder/MainActivity.kt`
- `firestore.rules`
- `lib/main.dart`
- `lib/core/services/telemetry.dart`
- `lib/core/utils/content.dart`
- `lib/features/profile/presentation/profile_page.dart`
- `lib/features/saved_items/data/saved_items_repository.dart`
- `lib/features/saved_items/domain/saved_item.dart`
- `lib/features/saved_items/presentation/bloc/saved_items_bloc.dart`
- `lib/features/saved_items/presentation/pages/library_page.dart`
- `lib/features/saved_items/presentation/widgets/saved_item_card.dart`
- `README.md`, `VALIDATION.md`, `V0_0_2_REPORT.md`

## Validation

No tests were added, changed or run, as explicitly requested. Earlier test results
in VALIDATION.md are historical and do not validate this release.

Commands run for formatting and validation:

```powershell
dart format lib
flutter pub get
dart format lib/core/utils/content.dart lib/features/saved_items/data/saved_items_repository.dart
flutter analyze
flutter build apk --debug
dart format lib/features/saved_items/presentation/pages/library_page.dart
git diff --check
dart format lib/core/services/telemetry.dart lib/main.dart
flutter analyze
```

Dependency resolution passed. The first analyzer run found an existing test
double's override was incompatible with the new optional telemetry argument.
The production API was made backward-compatible without editing tests; analysis
was rerun. Final analyzer/build results are recorded below after completion.

## Remaining limitations and suggested 0.0.3 scope

Authenticated real-device acceptance (cold/warm/background share, offline
restart/reconnect, favorites, deletion and external app/browser behavior) and
Analytics/Crashlytics console delivery were not exercised. Rule deployment is
still an operational step. The Android build retains the existing debug signing
and example application ID; it is not a store release.

The short-window URL guard is in-memory and resets when the user BLoC/process is
recreated; stable inbox document IDs still protect retries of retained shares.
Search/filtering use loaded batches of 100. Native iOS share intake is not
implemented, theme choice remains session-only, and device clock accuracy affects
date history. This release does not claim full device acceptance verification.

Recommended 0.0.3: address findings from real-device acceptance, production
signing/application identity, persistent appearance preferences, and focused
accessibility polish. No 0.0.3 work was started.
