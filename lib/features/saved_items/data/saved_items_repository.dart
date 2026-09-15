import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/telemetry.dart';
import '../../../core/utils/content.dart';
import '../domain/saved_item.dart';

abstract class SavedItemsRepository {
  Stream<List<SavedItem>> watch({int limit = 100});
  Future<bool> save(String id, Uri url, String text);
  Future<void> favorite(SavedItem item);
  Future<void> delete(String id);
}

class FirestoreSavedItemsRepository implements SavedItemsRepository {
  FirestoreSavedItemsRepository(
    FirebaseFirestore firestore,
    this.uid,
    this.telemetry,
    this.onCommitted,
  ) : collection = firestore.collection('users/$uid/saved_items');
  final String uid;
  final Telemetry telemetry;
  final Future<void> Function(String) onCommitted;
  final CollectionReference<Map<String, dynamic>> collection;
  @override
  Stream<List<SavedItem>> watch({int limit = 100}) => collection
      .orderBy('clientCreatedAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final items = snapshot.docs.map(SavedItem.fromDocument).toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
            if (accepted(doc) && !completer.isCompleted) completer.complete();
          },
          onError: (Object e, StackTrace s) {
            if (!completer.isCompleted) completer.completeError(e, s);
          },
        );
    try {
      unawaited(
        operation()
            .then((_) async {
              await committed?.call();
              if (!completer.isCompleted) completer.complete();
            })
            .catchError((Object e, StackTrace s) {
              if (!completer.isCompleted) {
                completer.completeError(e, s);
              } else if (!_failures.isClosed) {
                _failures.add(
                  'A queued change was rejected by the server. Please retry.',
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
  Future<void> dispose() async {
    for (final subscription in _confirmations.values) {
      await subscription.cancel();
    }
    _confirmations.clear();
    await _failures.close();
  }

  @override
  Future<bool> save(String id, Uri url, String text) async {
    final ref = collection.doc(id);
    try {
      final existing = await ref.get(const GetOptions(source: Source.cache));
      if (existing.exists) {
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
                      unawaited(
                        onCommitted(id).catchError((Object e, StackTrace s) {
                          unawaited(
                            telemetry.failure('share_confirmation', e, s),
                          );
                        }),
                      );
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
      committed: () => onCommitted(id),
    );
    return false;
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
