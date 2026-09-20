import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Stream<Plan> _plan;
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>();
    _plan = auth.repository.plan(auth.state.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 38,
            ),
          ),
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
            stream: _plan,
            builder: (context, snapshot) => ListTile(
              leading: CircleAvatar(
                child: Icon(
                  snapshot.data == Plan.pro
                      ? Icons.workspace_premium_rounded
                      : Icons.person_outline_rounded,
                ),
              ),
              title: const Text('Current plan'),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.ios_share_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to save content',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Open a link in TikTok, Instagram, YouTube, or another app. Tap Share, then choose Reel Reminder.',
                      ),
                    ],
                  ),
                ),
              ],
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
                  selected: {widget.themeMode},
                  onSelectionChanged: (value) =>
                      widget.onThemeChanged(value.first),
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
