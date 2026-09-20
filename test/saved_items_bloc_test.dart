import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_reminder/core/services/share_service.dart';
import 'package:reel_reminder/core/services/telemetry.dart';
import 'package:reel_reminder/core/utils/content.dart';
import 'package:reel_reminder/features/saved_items/data/saved_items_repository.dart';
import 'package:reel_reminder/features/saved_items/domain/saved_item.dart';
import 'package:reel_reminder/features/saved_items/presentation/bloc/saved_items_bloc.dart';

class FakeRepository implements SavedItemsRepository {
  @override
  Future<String> create(SavedItemDraft draft) async => 'created';

  @override
  Future<void> update(SavedItem item, SavedItemDraft draft) async {}

  final controller = StreamController<List<SavedItem>>.broadcast();
  final saved = <String>[];
  bool fail = false;
  bool confirmed = true;
  @override
  Stream<List<SavedItem>> watch({int limit = 100}) => controller.stream;
  @override
  Future<bool> save(String id, Uri url, String text) async {
    if (fail) throw StateError('offline failure');
    saved.add(id);
    return confirmed;
  }

  @override
  Future<bool> retryMetadata(SavedItem item) async => false;

  @override
  Future<void> favorite(SavedItem item) async {}
  @override
  Future<void> delete(String id) async {}
}

class FakeShares extends ShareService {
  final acknowledged = <String>[];
  @override
  Future<void> acknowledge(String id) async {
    acknowledged.add(id);
  }
}

class FakeTelemetry extends Telemetry {
  @override
  Future<void> event(String name) async {}
  @override
  Future<void> failure(
    String operation,
    Object error,
    StackTrace stack,
  ) async {}
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));
void main() {
  late FakeRepository repository;
  late FakeShares shares;
  late SavedItemsBloc bloc;
  setUp(() {
    repository = FakeRepository();
    shares = FakeShares();
    bloc = SavedItemsBloc(repository, shares, FakeTelemetry());
  });
  tearDown(() async {
    await bloc.close();
    await repository.controller.close();
  });
  test('rapid shares save once and acknowledge both', () async {
    final now = DateTime.now();
    bloc.add(ShareReceived(IncomingShare('a', 'https://youtu.be/abc', now)));
    bloc.add(
      ShareReceived(IncomingShare('b', 'Watch https://youtu.be/abc', now)),
    );
    await settle();
    expect(repository.saved, ['a']);
    expect(shares.acknowledged, ['a', 'b']);
  });
  test('failed save keeps inbox entry and allows retry', () async {
    final share = IncomingShare(
      'a',
      'https://instagram.com/reel/abc',
      DateTime.now(),
    );
    repository.fail = true;
    bloc.add(ShareReceived(share));
    await settle();
    expect(shares.acknowledged, isEmpty);
    expect(bloc.state.message, contains('kept'));
    repository.fail = false;
    bloc.add(ShareReceived(share));
    await settle();
    expect(repository.saved, ['a']);
    expect(shares.acknowledged, ['a']);
  });
  test('invalid share shows explanation without saving', () async {
    bloc.add(ShareReceived(IncomingShare('a', 'No link here', DateTime.now())));
    await settle();
    expect(repository.saved, isEmpty);
    expect(bloc.state.message, contains('valid'));
    expect(shares.acknowledged, ['a']);
  });
  test(
    'offline acceptance keeps original inbox entry across refresh',
    () async {
      repository.confirmed = false;
      final share = IncomingShare(
        'a',
        'https://youtu.be/offline',
        DateTime.now(),
      );
      bloc.add(ShareReceived(share));
      await settle();
      expect(shares.acknowledged, isEmpty);
      bloc.add(ShareReceived(share));
      await settle();
      expect(shares.acknowledged, isEmpty);
      repository.confirmed = true;
      bloc.add(ShareReceived(share));
      await settle();
      expect(shares.acknowledged, ['a']);
    },
  );
  test('loads items and filters/searches loaded data', () async {
    final now = DateTime.now();
    bloc.add(ItemsStarted());
    await settle();
    repository.controller.add([
      SavedItem(
        id: 'a',
        userId: 'u',
        url: 'https://youtu.be/a',
        platform: ContentPlatform.youtube,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await settle();
    expect(bloc.state.loading, false);
    bloc.add(SearchChanged('YOUTUBE'));
    bloc.add(FilterChanged(DateFilter.today));
    await settle();
    expect(bloc.state.visible(now, search: true), hasLength(1));
    bloc.add(SearchChanged('missing'));
    await settle();
    expect(bloc.state.visible(now, search: true), isEmpty);
  });
}
