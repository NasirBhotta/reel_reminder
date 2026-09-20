import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/share_service.dart';
import 'core/services/link_metadata_service.dart';
import 'core/services/telemetry.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/saved_items/data/saved_items_repository.dart';
import 'features/saved_items/presentation/bloc/saved_items_bloc.dart';
import 'features/saved_items/presentation/pages/library_page.dart';
import 'features/reminders/data/reminder_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final telemetry = Telemetry();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        telemetry.fatalFailure(
          'flutter_error',
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(telemetry.fatalFailure('uncaught_error', error, stack));
      return true;
    };
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      // A storage failure should not prevent the core app from starting.
    }
    final reminders = ReminderService();
    try {
      await reminders.initialize();
    } catch (error, stack) {
      unawaited(telemetry.failure('notification_initialization', error, stack));
    }
    runApp(
      MainApp(
        auth: AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
        telemetry: telemetry,
        preferences: preferences,
        reminders: reminders,
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not start Reel Reminder. Check Firebase configuration and restart the app.',
                  ),
                  TextButton(onPressed: main, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.auth,
    required this.telemetry,
    required this.preferences,
    required this.reminders,
  });
  final AuthRepository auth;
  final Telemetry telemetry;
  final SharedPreferences? preferences;
  final ReminderService reminders;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ThemeMode _theme = ThemeMode.system;
  final _shares = ShareService();
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _theme = switch (widget.preferences?.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _onboardingDone =
        widget.preferences?.getBool('onboarding_v1_done') ?? false;
  }

  void _changeTheme(ThemeMode mode) {
    setState(() => _theme = mode);
    unawaited(widget.preferences?.setString('theme_mode', mode.name));
  }

  Future<void> _finishOnboarding() async {
    if (!_onboardingDone) setState(() => _onboardingDone = true);
    try {
      await widget.preferences?.setBool('onboarding_v1_done', true);
    } catch (_) {
      // Continue into the app even if local preference storage is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
    value: widget.reminders,
    child: BlocProvider(
      create: (_) => AuthBloc(widget.auth, widget.telemetry),
      child: MaterialApp(
        title: 'Reel Reminder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _theme,
        home: !_onboardingDone
            ? OnboardingPage(onFinished: _finishOnboarding)
            : BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state.user != null && state.error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.error!)));
                  }
                },
                builder: (context, state) {
                  if (!state.ready) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (state.user == null) return const AuthPage();
                  final uid = state.user!.uid;
                  return BlocProvider(
                    key: ValueKey(uid),
                    create: (_) => SavedItemsBloc(
                      FirestoreSavedItemsRepository(
                        FirebaseFirestore.instance,
                        uid,
                        widget.telemetry,
                        _shares.acknowledge,
                        LinkMetadataService(),
                      ),
                      _shares,
                      widget.telemetry,
                      widget.reminders,
                    )..add(ItemsStarted()),
                    child: LibraryPage(
                      uid: uid,
                      shares: _shares,
                      telemetry: widget.telemetry,
                      themeMode: _theme,
                      onThemeChanged: _changeTheme,
                    ),
                  );
                },
              ),
      ),
    ),
  );
}
