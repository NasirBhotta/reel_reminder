# Validation — 15 September 2026

## Passed

- `flutter analyze`: no issues.
- `flutter test`: 24 tests, including URL/platform/date/duplicate logic, BLoC
  save/retry/offline acknowledgment behavior, and card rendering/actions.
- Firestore emulator: all 5 security-rule tests passed (owner CRUD, other-account
  and anonymous denial, schema/timestamp/ownership restrictions, Free/Pro rules).
- `flutter build apk --debug`: APK generated at
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Android 13 emulator: authentication UI launches; app registers as an Android text
  share target; cold/warm intents reach the inbox in the same running process;
  plain text containing a URL is preserved; inbox survives force-stop and
  relaunch while signed out.

## Still requires configured-account/device acceptance

- Actual YouTube/Instagram/browser Share Sheet selection through to a saved
  Firestore item in the timeline.
- Registration/login/session restoration against the intended Firebase project.
- Device offline save/restart/reconnect, server rejection recovery, and date
  transitions against real Firestore persistence.
- Open/copy/reshare/favorite/delete through the complete authenticated UI.
- Analytics and Crashlytics delivery in the Firebase console.
- Deployment of the supplied Firestore rules and release signing.

The full acceptance checklist is in README.md. The iOS Share Extension is not part
of the Android-first implementation.

## Environment notes

Flutter 3.44.4, Dart 3.12.2, Android Gradle Plugin 9.0.1. Kotlin incremental
compilation is disabled because this Windows workspace and the pub cache are on
different drives. Current Firebase plugins produce an upstream Kotlin Gradle
Plugin migration warning; the Android debug build succeeds.

Firebase emulator tests used Android Studio's bundled Java 21. An interrupted
emulator download succeeded on retry. No rules were deployed and no production
Firebase accounts were created during validation.

The Android emulator displayed a System UI not-responding dialog during UI
inspection. Native intake checks passed, but this run is not a full visual or
interactive acceptance test. The temporary read-only emulator was shut down.
