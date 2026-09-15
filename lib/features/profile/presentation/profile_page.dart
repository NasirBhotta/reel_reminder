import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 34,
          child: Icon(Icons.person_outline, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          auth.state.user?.email ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 28),
        Card(
          child: StreamBuilder<Plan>(
            stream: auth.repository.plan(auth.state.user!.uid),
            builder: (context, snapshot) => ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Your plan'),
              subtitle: Text(
                snapshot.hasError
                    ? 'Plan unavailable. Try again when connected.'
                    : snapshot.data == Plan.pro
                    ? 'Pro'
                    : 'Free',
              ),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance'),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (value) => onThemeChanged(value.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => auth.add(LogoutRequested()),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Reel Reminder · 0.1.0\nYour finds, in one place.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
