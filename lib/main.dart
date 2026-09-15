import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/share_service.dart';
import 'core/services/telemetry.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/saved_items/data/saved_items_repository.dart';
import 'features/saved_items/presentation/bloc/saved_items_bloc.dart';
import 'features/saved_items/presentation/pages/library_page.dart';
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
        telemetry.failure(
          'flutter_error',
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(telemetry.failure('uncaught_error', error, stack));
      return true;
    };
    runApp(
      MainApp(
        auth: AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
        telemetry: telemetry,
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
  const MainApp({super.key, required this.auth, required this.telemetry});
  final AuthRepository auth;
  final Telemetry telemetry;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ThemeMode _theme = ThemeMode.system;
  final _shares = ShareService();
  ThemeData _themeData(Brightness brightness) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF386A59),
      brightness: brightness,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AuthBloc(widget.auth, widget.telemetry),
    child: MaterialApp(
      title: 'Reel Reminder',
      debugShowCheckedModeBanner: false,
      theme: _themeData(Brightness.light),
      darkTheme: _themeData(Brightness.dark),
      themeMode: _theme,
      home: BlocConsumer<AuthBloc, AuthState>(
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
              ),
              _shares,
              widget.telemetry,
            )..add(ItemsStarted()),
            child: LibraryPage(
              uid: uid,
              shares: _shares,
              telemetry: widget.telemetry,
              themeMode: _theme,
              onThemeChanged: (mode) => setState(() => _theme = mode),
            ),
          );
        },
      ),
    ),
  );
}
