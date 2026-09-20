import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/content.dart';
import '../../../reminders/domain/reminder.dart';
import '../../domain/saved_item.dart';

enum ItemAction { details, open, copy, share, retryPreview, favorite, delete }

IconData platformIcon(ContentPlatform platform) => switch (platform) {
  ContentPlatform.youtube => Icons.play_circle_fill_rounded,
  ContentPlatform.instagram => Icons.camera_alt_rounded,
  ContentPlatform.tiktok => Icons.music_note_rounded,
  ContentPlatform.facebook => Icons.facebook_rounded,
  ContentPlatform.x => Icons.alternate_email_rounded,
  ContentPlatform.reddit => Icons.forum_rounded,
  ContentPlatform.website => Icons.language_rounded,
};

Color platformColor(ContentPlatform platform) => switch (platform) {
  ContentPlatform.youtube => const Color(0xFFFF0000),
  ContentPlatform.instagram => const Color(0xFFE1306C),
  ContentPlatform.tiktok => const Color(0xFF000000),
  ContentPlatform.facebook => const Color(0xFF1877F2),
  ContentPlatform.x => const Color(0xFF1DA1F2),
  ContentPlatform.reddit => const Color(0xFFFF4500),
  ContentPlatform.website => AppTheme.brand,
};

class SavedItemCard extends StatelessWidget {
  const SavedItemCard({super.key, required this.item, required this.onAction});
  final SavedItem item;
  final void Function(ItemAction) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final date = item.createdAt.toLocal();
    final image = Uri.tryParse(item.thumbnailUrl ?? '');
    final hasImage =
        image != null && image.scheme == 'https' && image.host.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onAction(ItemAction.details),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: hasImage
                      ? Image.network(
                          image.toString(),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          frameBuilder: (context, child, frame, _) =>
                              frame != null
                              ? child
                              : _ThumbnailPlaceholder(platform: item.platform),
                          errorBuilder: (_, _, _) =>
                              _ThumbnailPlaceholder(platform: item.platform),
                        )
                      : _ThumbnailPlaceholder(platform: item.platform),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          height: 28,
                          child: PopupMenuButton<ItemAction>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Item actions',
                            onSelected: onAction,
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: ItemAction.details,
                                child: Text('View details'),
                              ),
                              if (item.hasLink) ...[
                                const PopupMenuItem(
                                  value: ItemAction.open,
                                  child: Text('Open original'),
                                ),
                                const PopupMenuItem(
                                  value: ItemAction.copy,
                                  child: Text('Copy link'),
                                ),
                              ],
                              const PopupMenuItem(
                                value: ItemAction.share,
                                child: Text('Share again'),
                              ),
                              if (item.title == null ||
                                  item.thumbnailUrl == null)
                                const PopupMenuItem(
                                  value: ItemAction.retryPreview,
                                  child: Text('Retry preview'),
                                ),
                              const PopupMenuItem(
                                value: ItemAction.delete,
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          platformIcon(item.platform),
                          size: 15,
                          color: platformColor(item.platform),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.displaySource == item.displayDomain
                                ? item.displayDomain
                                : '${item.displaySource} · ${item.displayDomain}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (item.pending) ...[
                          const Tooltip(
                            message: 'Waiting to sync',
                            child: Icon(Icons.cloud_upload_outlined, size: 15),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            '${MaterialLocalizations.of(context).formatShortDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: item.isFavorite
                                ? 'Remove favorite'
                                : 'Favorite',
                            onPressed: () => onAction(ItemAction.favorite),
                            iconSize: 21,
                            icon: Icon(
                              item.isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: item.isFavorite
                                  ? (dark ? AppTheme.mint : AppTheme.brand)
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildReminderBadge(context, dark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderBadge(BuildContext context, bool dark) {
    if (item.hasReminder && item.reminderAt != null) {
      final isRepeating = item.repeatType != RepeatType.never;
      final bg = isRepeating
          ? (dark ? AppTheme.repeatBgDark : AppTheme.repeatBgLight)
          : (dark ? AppTheme.reminderBgDark : AppTheme.reminderBgLight);
      final text = isRepeating
          ? (dark ? AppTheme.repeatTextDark : AppTheme.repeatTextLight)
          : (dark ? AppTheme.reminderTextDark : AppTheme.reminderTextLight);
      final icon = isRepeating ? Icons.repeat_rounded : Icons.schedule_rounded;

      final reminderDate = item.reminderAt!.toLocal();
      final dateStr = _formatReminderTime(context, reminderDate);
      final label = isRepeating
          ? 'Repeat ${_repeatLabel(item.repeatType)}'
          : 'Reminder: $dateStr';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: text),
            const SizedBox(width: 4.5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? AppTheme.neutralBgDark : AppTheme.neutralBgLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 11.5,
            color: dark ? AppTheme.neutralTextDark : AppTheme.neutralTextLight,
          ),
          const SizedBox(width: 4),
          Text(
            'No reminder',
            style: TextStyle(
              color: dark
                  ? AppTheme.neutralTextDark
                  : AppTheme.neutralTextLight,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReminderTime(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    final timeStr = TimeOfDay.fromDateTime(date).format(context);

    if (diff == 0) return 'Today · $timeStr';
    if (diff == 1) return 'Tomorrow · $timeStr';
    return '${MaterialLocalizations.of(context).formatShortDate(date)} · $timeStr';
  }

  String _repeatLabel(RepeatType repeat) => switch (repeat) {
    RepeatType.daily => 'daily',
    RepeatType.weekly => 'weekly',
    RepeatType.monthly => 'monthly',
    RepeatType.custom => 'custom',
    RepeatType.never => 'never',
  };
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.platform});
  final ContentPlatform platform;

  @override
  Widget build(BuildContext context) {
    final bg = switch (platform) {
      ContentPlatform.facebook => const Color(0xFF1877F2),
      ContentPlatform.youtube => const Color(0xFFFF0000),
      ContentPlatform.tiktok => const Color(0xFF000000),
      ContentPlatform.instagram => const Color(0xFF833AB4),
      ContentPlatform.x => const Color(0xFF111111),
      ContentPlatform.reddit => const Color(0xFFFF4500),
      ContentPlatform.website =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B382D)
            : AppTheme.paleMint,
    };

    final fg = switch (platform) {
      ContentPlatform.website =>
        Theme.of(context).brightness == Brightness.dark
            ? AppTheme.mint
            : AppTheme.brand,
      _ => Colors.white,
    };

    return ColoredBox(
      color: bg,
      child: Center(child: Icon(platformIcon(platform), size: 32, color: fg)),
    );
  }
}
