import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_reminder/core/utils/content.dart';
import 'package:reel_reminder/features/saved_items/domain/saved_item.dart';

void main() {
  test('old saved item data works without v0.0.3 metadata fields', () {
    final created = Timestamp.fromDate(DateTime(2026, 9, 19, 12));
    final item = SavedItem.fromData(
      id: 'old',
      data: {
        'userId': 'user',
        'url': 'https://example.com/old',
        'sharedText': null,
        'title': null,
        'thumbnailUrl': null,
        'platform': 'website',
        'createdAt': created,
        'updatedAt': created,
        'clientCreatedAt': created,
        'isFavorite': false,
      },
    );

    expect(item.platform, ContentPlatform.website);
    expect(item.title, isNull);
    expect(item.description, isNull);
    expect(item.siteName, isNull);
    expect(item.domain, isNull);
    expect(item.displayTitle, 'example.com');
  });
}
