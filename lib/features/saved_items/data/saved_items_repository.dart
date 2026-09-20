import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/link_metadata_service.dart';
import '../../../core/services/telemetry.dart';
import '../../../core/utils/content.dart';
import '../domain/saved_item.dart';

abstract class SavedItemsRepository {
  Stream<List<SavedItem>> watch({int limit = 100});
  Future<bool> save(String id, Uri url, String text);
  Future<bool> retryMetadata(SavedItem item);
  Future<String> create(SavedItemDraft draft);
  Future<void> update(SavedItem item, SavedItemDraft draft);
  Future<void> favorite(SavedItem item);
  Future<void> delete(String id);
}

class FirestoreSavedItemsRepository implements SavedItemsRepository {
  FirestoreSavedItemsRepository(
    FirebaseFirestore firestore,
    this.uid,
    this.telemetry,
    this.onCommitted,
    this.metadataService,
  ) : collection = firestore.collection('users/$uid/saved_items');
  final String uid;
  final Telemetry telemetry;
  final Future<void> Function(String) onCommitted;
  final LinkMetadataService metadataService;
  final CollectionReference<Map<String, dynamic>> collection;
  @override
  Stream<List<SavedItem>> watch({int limit = 100}) => collection
      .orderBy('clientCreatedAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final items = snapshot.docs.map(SavedItem.fromDocument).toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _scheduleLegacyMetadata(items);
        return items;
      });
  // Wait for the local snapshot, not the server acknowledgement: offline writes
  // remain queued by Firestore. Surface eventual server rejection separately.
  Future<void> _write(
    DocumentReference<Map<String, dynamic>> ref,
    Future<void> Function() operation,
    bool Function(DocumentSnapshot<Map<String, dynamic>>) accepted, {
    Future<void> Function()? committed,
  }) async {
    final completer = Completer<void>();
    final subscription = ref
        .snapshots(includeMetadataChanges: true)
        .listen(
          (doc) {
            if (doc.metadata.hasPendingWrites &&
                accepted(doc) &&
                !completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (Object e, StackTrace s) {
            if (!completer.isCompleted) completer.completeError(e, s);
          },
        );
    try {
      unawaited(
        operation()
            .then((_) async {
              if (!completer.isCompleted) completer.complete();
              try {
                await committed?.call();
              } catch (e, s) {
                // The write succeeded. Keep the inbox entry for an idempotent retry.
                unawaited(telemetry.failure('share_confirmation', e, s));
                if (!_failures.isClosed) {
                  _failures.add(
                    'Your link was saved. Tap refresh to finish processing the share.',
                  );
                }
              }
            })
            .catchError((Object e, StackTrace s) {
              if (!completer.isCompleted) {
                completer.completeError(e, s);
              } else if (!_failures.isClosed) {
                _failures.add(
                  e is FirebaseException &&
                          const [
                            'permission-denied',
                            'unauthenticated',
                          ].contains(e.code)
                      ? 'Could not sync this change. Sign in again and retry.'
                      : 'A queued change could not sync. Tap refresh to retry.',
                );
              }
              unawaited(telemetry.failure('firestore_write', e, s));
            }),
      );
      await completer.future.timeout(const Duration(seconds: 15));
    } finally {
      await subscription.cancel();
    }
  }

  final _failures = StreamController<String>.broadcast();
  final _confirmations =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  Stream<String> get failures => _failures.stream;
  bool _disposed = false;
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _confirmations.values) {
      await subscription.cancel();
    }
    _confirmations.clear();
    metadataService.close();
    await _failures.close();
  }

  @override
  Future<bool> save(String id, Uri url, String text) async {
    final ref = collection.doc(id);
    try {
      final existing = await ref.get(const GetOptions(source: Source.cache));
      if (existing.exists) {
        _startMetadataIfNeeded(id, url, existing.data());
        if (!existing.metadata.hasPendingWrites) return true;
        // Reattach confirmation after process restart without rewriting timestamps.
        _confirmations.putIfAbsent(
          id,
          () => ref
              .snapshots(includeMetadataChanges: true)
              .listen(
                (doc) {
                  if (!doc.metadata.hasPendingWrites &&
                      !doc.metadata.isFromCache) {
                    unawaited(_confirmations.remove(id)?.cancel());
                    if (doc.exists) {
                      unawaited(_finishCommittedShare(id, url, doc.data()));
                    } else if (!_failures.isClosed) {
                      _failures.add(
                        'A saved share could not sync. Tap refresh to retry.',
                      );
                    }
                  }
                },
                onError: (Object e, StackTrace s) {
                  unawaited(_confirmations.remove(id)?.cancel());
                  unawaited(telemetry.failure('share_confirmation', e, s));
                  if (!_failures.isClosed) {
                    _failures.add(
                      'Could not confirm saved share. Tap refresh to retry.',
                    );
                  }
                },
              ),
        );
        return false;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
    }
    await _write(
      ref,
      () => ref.set({
        'userId': uid,
        'url': url.toString(),
        'sharedText': text,
        'title': null,
        'thumbnailUrl': null,
        'platform': PlatformDetector.detect(url).name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.now(),
        'isFavorite': false,
      }),
      (doc) => doc.exists,
      committed: () async {
        await _finishCommittedShare(id, url, const {});
      },
    );
    return false;
  }

  @override
  Future<String> create(SavedItemDraft draft) async {
    final ref = collection.doc();
    final uri = draft.url;
    await ref.set({
      'userId': uid,
      'url': uri?.toString() ?? '',
      'sharedText': draft.content,
      'title': draft.title,
      'thumbnailUrl': null,
      'platform': uri == null
          ? ContentPlatform.website.name
          : PlatformDetector.detect(uri).name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'clientCreatedAt': Timestamp.now(),
      'isFavorite': false,
      'tag': draft.tag,
      'notes': draft.notes,
      'hasReminder': draft.hasReminder,
      'reminderAt': draft.reminderAt == null
          ? null
          : Timestamp.fromDate(draft.reminderAt!),
      'repeatType': draft.repeatType.name,
      'customIntervalDays': draft.customIntervalDays,
    });
    if (uri != null) {
      _startMetadataIfNeeded(ref.id, uri, {'title': draft.title});
    }
    return ref.id;
  }

  @override
  Future<void> update(SavedItem item, SavedItemDraft draft) =>
      collection.doc(item.id).update({
        'title': draft.title,
        'tag': draft.tag,
        'notes': draft.notes,
        'hasReminder': draft.hasReminder,
        'reminderAt': draft.reminderAt == null
            ? null
            : Timestamp.fromDate(draft.reminderAt!),
        'repeatType': draft.repeatType.name,
        'customIntervalDays': draft.customIntervalDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  final _metadataInFlight = <String>{};
  final _metadataAttemptedThisSession = <String>{};
  final _legacyMetadataQueue = <SavedItem>[];
  bool _drainingLegacyMetadata = false;

  Future<void> _finishCommittedShare(
    String id,
    Uri url,
    Map<String, dynamic>? data,
  ) async {
    try {
      await onCommitted(id);
    } catch (e, s) {
      unawaited(telemetry.failure('share_confirmation', e, s));
    } finally {
      _startMetadataIfNeeded(id, url, data);
    }
  }

  void _scheduleLegacyMetadata(List<SavedItem> items) {
    for (final item in items) {
      if (!item.pending &&
          item.metadataStatus == null &&
          item.title == null &&
          item.thumbnailUrl == null &&
          _metadataAttemptedThisSession.add(item.id)) {
        _legacyMetadataQueue.add(item);
      }
    }
    if (!_drainingLegacyMetadata && _legacyMetadataQueue.isNotEmpty) {
      unawaited(_drainLegacyMetadata());
    }
  }

  Future<void> _drainLegacyMetadata() async {
    _drainingLegacyMetadata = true;
    try {
      while (!_disposed && _legacyMetadataQueue.isNotEmpty) {
        final item = _legacyMetadataQueue.removeAt(0);
        final uri = Uri.tryParse(item.url);
        if (uri != null && _metadataInFlight.add(item.id)) {
          await _fetchAndStoreMetadata(item.id, uri, existingTitle: item.title);
        }
      }
    } finally {
      _drainingLegacyMetadata = false;
    }
  }

  void _startMetadataIfNeeded(String id, Uri url, Map<String, dynamic>? data) {
    final status = data?['metadataStatus'];
    if ((status != null && status != 'pending') || !_metadataInFlight.add(id)) {
      return;
    }
    _metadataAttemptedThisSession.add(id);
    unawaited(
      _fetchAndStoreMetadata(id, url, existingTitle: data?['title'] as String?),
    );
  }

  Future<bool> _fetchAndStoreMetadata(
    String id,
    Uri url, {
    String? existingTitle,
  }) async {
    var resolved = false;
    try {
      final metadata = await metadataService.fetch(url);
      if (_disposed) return false;
      resolved = metadata?.hasPreview == true;
      await collection.doc(id).update({
        if (existingTitle == null) 'title': metadata?.title,
        'description': metadata?.description,
        'thumbnailUrl': metadata?.thumbnailUrl,
        'siteName': metadata?.siteName,
        'domain': metadata?.domain ?? url.host.toLowerCase(),
        'metadataStatus': metadata?.hasPreview == true
            ? 'complete'
            : 'unavailable',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, s) {
      resolved = false;
      if (e.code != 'not-found') {
        unawaited(telemetry.failure('metadata_update', e, s));
        if (e.code == 'permission-denied' && !_failures.isClosed) {
          _failures.add('Link saved, but its preview could not be updated.');
        }
      }
    } catch (e, s) {
      resolved = false;
      unawaited(telemetry.failure('metadata_fetch', e, s));
    } finally {
      _metadataInFlight.remove(id);
    }
    return resolved;
  }

  @override
  Future<bool> retryMetadata(SavedItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || !_metadataInFlight.add(item.id)) return false;
    _metadataAttemptedThisSession.add(item.id);
    return _fetchAndStoreMetadata(item.id, uri, existingTitle: item.title);
  }

  @override
  Future<void> favorite(SavedItem item) {
    final ref = collection.doc(item.id);
    return _write(
      ref,
      () => ref.update({
        'isFavorite': !item.isFavorite,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      (doc) => doc.data()?['isFavorite'] == !item.isFavorite,
    );
  }

  @override
  Future<void> delete(String id) {
    final ref = collection.doc(id);
    return _write(ref, ref.delete, (doc) => !doc.exists);
  }
}
