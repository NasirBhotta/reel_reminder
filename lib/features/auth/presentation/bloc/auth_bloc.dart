import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/telemetry.dart';
import '../../data/auth_repository.dart';

sealed class AuthEvent {}

class AuthChanged extends AuthEvent {
  AuthChanged(this.user);
  final User? user;
}

class AuthSubmitted extends AuthEvent {
  AuthSubmitted(this.email, this.password, {this.register = false});
  final String email, password;
  final bool register;
}

class LogoutRequested extends AuthEvent {}

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.loading = false,
    this.ready = false,
    this.error,
  });
  final User? user;
  final bool loading, ready;
  final String? error;
  @override
  List<Object?> get props => [user?.uid, loading, ready, error];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.repository, this.telemetry) : super(const AuthState()) {
    on<AuthChanged>((event, emit) {
      emit(AuthState(user: event.user, ready: true));
      if (event.user != null) {
        unawaited(
          repository.ensureProfile(event.user!.uid).catchError((
            Object e,
            StackTrace s,
          ) {
            unawaited(telemetry.failure('profile_initialization', e, s));
          }),
        );
      }
    });
    on<AuthSubmitted>((event, emit) async {
      if (state.loading) return;
      emit(AuthState(user: state.user, ready: true, loading: true));
      try {
        if (event.register) {
          await repository.register(event.email, event.password);
        } else {
          await repository.login(event.email, event.password);
        }
        unawaited(
          telemetry.event(
            event.register ? 'account_created' : 'login_completed',
          ),
        );
      } on FirebaseAuthException catch (e) {
        emit(
          AuthState(
            ready: true,
            error: switch (e.code) {
              'email-already-in-use' => 'An account already uses this email.',
              'weak-password' =>
                'Choose a stronger password (at least 6 characters).',
              'invalid-email' => 'Enter a valid email address.',
              'network-request-failed' =>
                'Check your connection and try again.',
              'too-many-requests' =>
                'Too many attempts. Please try again later.',
              _ => 'Could not sign in. Check your details and try again.',
            },
          ),
        );
      } catch (e, s) {
        unawaited(telemetry.failure('authentication', e, s));
        emit(
          const AuthState(
            ready: true,
            error: 'Authentication failed. Please try again.',
          ),
        );
      }
    });
    on<LogoutRequested>((event, emit) async {
      try {
        await repository.logout();
      } catch (e, s) {
        unawaited(telemetry.failure('logout', e, s));
        emit(
          AuthState(
            user: state.user,
            ready: true,
            error: 'Could not sign out. Try again.',
          ),
        );
      }
    });
    _subscription = repository.changes.listen((user) => add(AuthChanged(user)));
  }
  final AuthRepository repository;
  final Telemetry telemetry;
  late final StreamSubscription<User?> _subscription;
  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
