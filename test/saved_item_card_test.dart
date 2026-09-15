import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_reminder/core/utils/content.dart';
import 'package:reel_reminder/features/saved_items/domain/saved_item.dart';
import 'package:reel_reminder/features/saved_items/presentation/widgets/saved_item_card.dart';

void main() {
  testWidgets('missing metadata remains useful and actions are accessible', (
    tester,
  ) async {
    final actions = <ItemAction>[];
    final now = DateTime(2026, 9, 15, 14, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedItemCard(
            item: SavedItem(
              id: 'a',
              userId: 'u',
              url: 'https://example.com/article',
              platform: ContentPlatform.website,
              createdAt: now,
              updatedAt: now,
              pending: true,
            ),
            onAction: actions.add,
          ),
        ),
      ),
    );
    expect(find.text('example.com'), findsOneWidget);
    expect(find.byTooltip('Waiting to sync'), findsOneWidget);
    await tester.tap(find.text('example.com'));
    expect(actions, [ItemAction.open]);
    await tester.tap(find.byTooltip('Favorite'));
    expect(actions.last, ItemAction.favorite);
    await tester.tap(find.byTooltip('Item actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(actions.last, ItemAction.copy);
    expect(tester.takeException(), isNull);
  });
}
