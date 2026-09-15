import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/content.dart';

class SavedItem {
  const SavedItem({
    required this.id,
    required this.userId,
    required this.url,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
    this.sharedText,
    this.title,
    this.thumbnailUrl,
    this.isFavorite = false,
    this.pending = false,
  });
  final String id, userId, url;
  final String? sharedText, title, thumbnailUrl;
  final ContentPlatform platform;
  final DateTime createdAt, updatedAt;
  final bool isFavorite, pending;
  factory SavedItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final local = (data['clientCreatedAt'] as Timestamp).toDate();
    return SavedItem(
      id: doc.id,
      userId: data['userId'] as String,
      url: data['url'] as String,
      sharedText: data['sharedText'] as String?,
      title: data['title'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      platform: ContentPlatform.values.firstWhere(
        (p) => p.name == data['platform'],
        orElse: () => ContentPlatform.website,
      ),
      // Preserve when the user saved it, even if an offline write syncs days later.
      createdAt: local,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? local,
      isFavorite: data['isFavorite'] as bool? ?? false,
      pending: doc.metadata.hasPendingWrites,
    );
  }
  bool matches(String query) => [title, sharedText, url, platform.label]
      .whereType<String>()
      .any((value) => value.toLowerCase().contains(query.trim().toLowerCase()));
}
