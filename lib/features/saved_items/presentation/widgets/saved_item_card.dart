import 'package:flutter/material.dart';
import '../../domain/saved_item.dart';

enum ItemAction { open, copy, share, favorite, delete }

class SavedItemCard extends StatelessWidget {
  const SavedItemCard({super.key, required this.item, required this.onAction});
  final SavedItem item;
  final void Function(ItemAction) onAction;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = item.createdAt.toLocal();
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!
        : item.sharedText?.trim().isNotEmpty == true &&
              item.sharedText!.trim() != item.url
        ? item.sharedText!
        : Uri.tryParse(item.url)?.host ?? 'Saved link';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onAction(ItemAction.open),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.platform.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (item.pending)
                    const Tooltip(
                      message: 'Waiting to sync',
                      child: Icon(Icons.cloud_upload_outlined, size: 18),
                    ),
                  IconButton(
                    tooltip: item.isFavorite ? 'Remove favorite' : 'Favorite',
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
              if (item.thumbnailUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Image.network(
                    item.thumbnailUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                item.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                '${MaterialLocalizations.of(context).formatShortDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
