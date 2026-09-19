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

  Future<void> failure(String operation, Object error, StackTrace stack) =>
      _recordFailure(operation, error, stack);

  Future<void> fatalFailure(String operation, Object error, StackTrace stack) =>
      _recordFailure(operation, error, stack, fatal: true);

  Future<void> _recordFailure(
    String operation,
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    // Do not send URLs, shared text, email addresses, or raw exception messages.
    try {
      await FirebaseCrashlytics.instance.recordError(
        '$operation: ${error.runtimeType}',
        stack,
        reason: operation,
        fatal: fatal,
      );
    } catch (_) {
      /* Reporting must not crash the app. */
    }
  }
}
