import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/content.dart';
import '../../reminders/domain/reminder.dart';

class SavedItemDraft {
  const SavedItemDraft({
    required this.content,
    this.url,
    this.title,
    this.tag,
    this.notes,
    this.reminderAt,
    this.repeatType = RepeatType.never,
    this.customIntervalDays,
  });
  final String content;
  final Uri? url;
  final String? title, tag, notes;
  final DateTime? reminderAt;
  final RepeatType repeatType;
  final int? customIntervalDays;
  bool get hasReminder => reminderAt != null;
}

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
    this.description,
    this.thumbnailUrl,
    this.siteName,
    this.domain,
    this.metadataStatus,
    this.isFavorite = false,
    this.pending = false,
    this.tag,
    this.notes,
    this.hasReminder = false,
    this.reminderAt,
    this.repeatType = RepeatType.never,
    this.customIntervalDays,
  });
  final String id, userId, url;
  final String? sharedText, title, description, thumbnailUrl, siteName, domain;
  final String? metadataStatus;
  final ContentPlatform platform;
  final DateTime createdAt, updatedAt;
  final bool isFavorite, pending;
  final String? tag, notes;
  final bool hasReminder;
  final DateTime? reminderAt;
  final RepeatType repeatType;
  final int? customIntervalDays;
  factory SavedItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SavedItem.fromData(
        id: doc.id,
        data: doc.data() ?? const {},
        pending: doc.metadata.hasPendingWrites,
      );

  factory SavedItem.fromData({
    required String id,
    required Map<String, dynamic> data,
    bool pending = false,
  }) {
    String? stringValue(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    final created = data['clientCreatedAt'] ?? data['createdAt'];
    final local = created is Timestamp ? created.toDate() : DateTime.now();
    return SavedItem(
      id: id,
      userId: data['userId'] as String? ?? '',
      url: data['url'] as String? ?? '',
      sharedText: stringValue('sharedText'),
      title: stringValue('title'),
      description: stringValue('description'),
      thumbnailUrl: stringValue('thumbnailUrl'),
      siteName: stringValue('siteName'),
      domain: stringValue('domain'),
      metadataStatus: stringValue('metadataStatus'),
      platform: ContentPlatform.values.firstWhere(
        (p) => p.name == data['platform'],
        orElse: () => ContentPlatform.website,
      ),
      // Preserve when the user saved it, even if an offline write syncs days later.
      createdAt: local,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? local,
      isFavorite: data['isFavorite'] as bool? ?? false,
      pending: pending,
      tag: stringValue('tag'),
      notes: stringValue('notes'),
      hasReminder: data['hasReminder'] as bool? ?? false,
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      repeatType: repeatTypeFrom(data['repeatType']),
      customIntervalDays: data['customIntervalDays'] as int?,
    );
  }
  bool matches(String query) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final needle = normalize(query);
    return needle.isEmpty ||
        [
          title,
          description,
          sharedText,
          url,
          siteName,
          domain,
          platform.label,
          if (platform == ContentPlatform.x) 'Twitter',
        ].whereType<String>().any((value) => normalize(value).contains(needle));
  }

  bool get hasLink {
    final value = Uri.tryParse(url);
    return value != null &&
        (value.scheme == 'http' || value.scheme == 'https') &&
        value.host.isNotEmpty;
  }

  String get displayDomain {
    if (domain?.trim().isNotEmpty == true) return domain!;
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host?.isNotEmpty == true ? host! : 'Saved note';
  }

  String get displayTitle {
    if (title?.trim().isNotEmpty == true) return title!.trim();
    final text = sharedText?.trim();
    if (text != null && text.isNotEmpty && text != url) return text;
    return displayDomain;
  }

  String? get displayDescription {
    final value = description?.trim();
    if (value != null && value.isNotEmpty && value != displayTitle) {
      return value;
    }
    final text = sharedText?.trim();
    if (text != null &&
        text.isNotEmpty &&
        text != url &&
        text != displayTitle) {
      return text;
    }
    return null;
  }

  String get displaySource {
    final site = siteName?.trim();
    if (site != null && site.isNotEmpty) return site;
    return platform.label;
  }
}
