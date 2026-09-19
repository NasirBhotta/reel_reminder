import 'package:flutter/material.dart';
import '../../../../core/utils/content.dart';
import '../../domain/saved_item.dart';

enum ItemAction { details, open, copy, share, retryPreview, favorite, delete }

IconData platformIcon(ContentPlatform platform) => switch (platform) {
  ContentPlatform.youtube => Icons.play_circle_outline_rounded,
  ContentPlatform.instagram => Icons.camera_alt_outlined,
  ContentPlatform.tiktok => Icons.music_note_rounded,
  ContentPlatform.facebook => Icons.people_outline_rounded,
  ContentPlatform.x => Icons.alternate_email_rounded,
  ContentPlatform.reddit => Icons.forum_outlined,
  ContentPlatform.website => Icons.language_rounded,
};

class SavedItemCard extends StatelessWidget {
  const SavedItemCard({super.key, required this.item, required this.onAction});
  final SavedItem item;
  final void Function(ItemAction) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          height: 30,
                          child: PopupMenuButton<ItemAction>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Item actions',
                            onSelected: onAction,
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: ItemAction.details,
                                child: Text('View details'),
                              ),
                              const PopupMenuItem(
                                value: ItemAction.open,
                                child: Text('Open original'),
                              ),
                              const PopupMenuItem(
                                value: ItemAction.copy,
                                child: Text('Copy link'),
                              ),
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
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          platformIcon(item.platform),
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.displaySource == item.displayDomain
                                ? item.displayDomain
                                : '${item.displaySource} · ${item.displayDomain}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
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
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          height: 30,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: item.isFavorite
                                ? 'Remove favorite'
                                : 'Favorite',
                            onPressed: () => onAction(ItemAction.favorite),
                            iconSize: 20,
                            icon: Icon(
                              item.isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.platform});
  final ContentPlatform platform;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        platformIcon(platform),
        size: 30,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
