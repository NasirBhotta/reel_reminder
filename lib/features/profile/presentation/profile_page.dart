import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final userEmail = auth.state.user?.email ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Your account',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your preferences and settings.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? const Color(0xFF19382B)
                      : const Color(0xFFD4EFE3),
                  border: Border.all(
                    color: dark ? AppTheme.mint : AppTheme.brand,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: CustomPaint(
                    size: const Size(96, 96),
                    painter: _AvatarPainter(
                      dark: dark,
                      initial: userEmail.isNotEmpty
                          ? userEmail.trim()[0].toUpperCase()
                          : 'R',
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: dark ? AppTheme.mint : AppTheme.brand,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 15,
                    color: dark ? AppTheme.ink : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userEmail,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 26),
        Card(
          child: StreamBuilder<Plan>(
            stream: _plan,
            builder: (context, snapshot) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEAA7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD97706),
                  size: 26,
                ),
              ),
              title: Text(
                'Current plan',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    snapshot.hasError
                        ? 'Plan unavailable'
                        : snapshot.data == Plan.pro
                        ? 'Pro'
                        : 'Free',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlock more features soon!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: dark ? const Color(0xFF12231D) : const Color(0xFFF0F9F5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1B382D) : AppTheme.paleMint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    color: dark ? AppTheme.mint : AppTheme.brand,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to save content',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Open a link in TikTok, Instagram, YouTube, or another app. Tap Share, then choose Reel Reminder.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 18,
                      color: dark ? AppTheme.mint : AppTheme.brand,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appearance',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.check_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
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
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 28),
        Text(
          'Reel Reminder · 0.1.0\nYour finds, in one place.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter({required this.dark, required this.initial});
  final bool dark;
  final String initial;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    final bgPaint = Paint()
      ..color = dark ? const Color(0xFF163226) : const Color(0xFFD6EFE4);
    canvas.drawCircle(center, size.width / 2, bgPaint);

    // Body / Shoulders
    final bodyPaint = Paint()
      ..color = dark ? const Color(0xFF2C5E4A) : const Color(0xFFE2A676);
    final bodyPath = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.65,
        size.width * 0.85,
        size.height,
      )
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Head
    final skinPaint = Paint()..color = const Color(0xFFF8C9A8);
    final headCenter = Offset(size.width * 0.5, size.height * 0.44);
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter,
        width: size.width * 0.42,
        height: size.height * 0.48,
      ),
      skinPaint,
    );

    // Hair
    final hairPaint = Paint()..color = const Color(0xFF332017);
    final hairPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.2,
        size.width * 0.5,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.2,
        size.width * 0.72,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.32,
        size.width * 0.5,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.32,
        size.width * 0.28,
        size.height * 0.5,
      )
      ..close();
    canvas.drawPath(hairPath, hairPaint);
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.initial != initial;
}
