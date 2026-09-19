import 'package:flutter/material.dart';
import '../../../../core/utils/content.dart';
import '../../domain/saved_item.dart';

enum ItemAction { details, open, copy, share, favorite, delete }

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
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => onAction(ItemAction.details),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              SizedBox(
                height: 168,
                width: double.infinity,
                child: Image.network(
                  image.toString(),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  frameBuilder: (context, child, frame, _) => frame != null
                      ? child
                      : _ImagePlaceholder(platform: item.platform),
                  errorBuilder: (_, _, _) =>
                      _ImagePlaceholder(platform: item.platform),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          platformIcon(item.platform),
                          size: 19,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displaySource,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            if (item.displaySource != item.displayDomain)
                              Text(
                                item.displayDomain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                      if (item.pending)
                        const Tooltip(
                          message: 'Waiting to sync',
                          child: Icon(Icons.cloud_upload_outlined, size: 18),
                        ),
                      IconButton(
                        tooltip: item.isFavorite
                            ? 'Remove favorite'
                            : 'Favorite',
                        onPressed: () => onAction(ItemAction.favorite),
                        icon: Icon(
                          item.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                      ),
                      PopupMenuButton<ItemAction>(
                        tooltip: 'Item actions',
                        onSelected: onAction,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: ItemAction.details,
                            child: Text('View details'),
                          ),
                          PopupMenuItem(
                            value: ItemAction.open,
                            child: Text('Open original'),
                          ),
                          PopupMenuItem(
                            value: ItemAction.copy,
                            child: Text('Copy link'),
                          ),
                          PopupMenuItem(
                            value: ItemAction.share,
                            child: Text('Share again'),
                          ),
                          PopupMenuItem(
                            value: ItemAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (item.displayDescription case final description?) ...[
                    const SizedBox(height: 7),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${MaterialLocalizations.of(context).formatShortDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      if (item.metadataStatus == 'pending')
                        Text(
                          'Loading preview…',
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.platform});
  final ContentPlatform platform;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        platformIcon(platform),
        size: 42,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
