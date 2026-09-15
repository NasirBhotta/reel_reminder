import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class Telemetry {
  Future<void> event(String name) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name);
    } catch (_) {
      /* Never block saving. */
    }
  }

  Future<void> failure(String operation, Object error, StackTrace stack) async {
    // Do not send URLs, shared text, email addresses, or raw exception messages.
    try {
      await FirebaseCrashlytics.instance.recordError(
        '$operation: ${error.runtimeType}',
        stack,
        reason: operation,
      );
    } catch (_) {
      /* Reporting must not crash the app. */
    }
  }
}
