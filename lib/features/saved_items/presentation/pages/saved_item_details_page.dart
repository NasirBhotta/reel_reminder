import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/saved_item.dart';
import '../bloc/saved_items_bloc.dart';
import '../widgets/saved_item_card.dart';

class SavedItemDetailsPage extends StatelessWidget {
  const SavedItemDetailsPage({
    super.key,
    required this.itemId,
    required this.onAction,
  });

  final String itemId;
  final Future<void> Function(SavedItem, ItemAction) onAction;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SavedItemsBloc, SavedItemsState>(
    builder: (context, state) {
      final matches = state.items.where((item) => item.id == itemId);
      if (matches.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
        return const Scaffold(body: SizedBox.shrink());
      }
      final item = matches.first;
      final image = Uri.tryParse(item.thumbnailUrl ?? '');
      final showImage =
          image != null && image.scheme == 'https' && image.host.isNotEmpty;
      final date = item.createdAt.toLocal();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved item'),
          actions: [
            IconButton(
              tooltip: 'Delete',
              onPressed: () => onAction(item, ItemAction.delete),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (showImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  image.toString(),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(platformIcon(item.platform), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(item.displaySource)),
                IconButton(
                  tooltip: item.isFavorite ? 'Remove favorite' : 'Favorite',
                  onPressed: () => onAction(item, ItemAction.favorite),
                  icon: Icon(
                    item.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.displayTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (item.description case final description?) ...[
              const SizedBox(height: 14),
              Text(description, style: Theme.of(context).textTheme.bodyLarge),
            ],
            if (item.sharedText case final sharedText?) ...[
              const SizedBox(height: 24),
              Text(
                'Shared text',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              SelectableText(sharedText),
            ],
            const SizedBox(height: 24),
            Text(
              'Original link',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SelectableText(item.url),
            const SizedBox(height: 20),
            Text(
              'Saved ${MaterialLocalizations.of(context).formatFullDate(date)} at ${TimeOfDay.fromDateTime(date).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onAction(item, ItemAction.open),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open original'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(item, ItemAction.copy),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(item, ItemAction.share),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
