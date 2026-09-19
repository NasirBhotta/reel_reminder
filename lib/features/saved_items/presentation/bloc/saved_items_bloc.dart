import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/services/telemetry.dart';
import '../../../../core/utils/content.dart';
import '../../data/saved_items_repository.dart';
import '../../domain/saved_item.dart';

sealed class SavedItemsEvent {}

class ItemsStarted extends SavedItemsEvent {
  ItemsStarted({this.loadMore = false});
  final bool loadMore;
}

class ItemsReceived extends SavedItemsEvent {
  ItemsReceived(this.items);
  final List<SavedItem> items;
}

class ItemsFailed extends SavedItemsEvent {
  ItemsFailed(this.message);
  final String message;
}

class ShareReceived extends SavedItemsEvent {
  ShareReceived(this.share);
  final IncomingShare share;
}

class FilterChanged extends SavedItemsEvent {
  FilterChanged(this.filter);
  final DateFilter filter;
}

class SearchChanged extends SavedItemsEvent {
  SearchChanged(this.query);
  final String query;
}

class FavoriteRequested extends SavedItemsEvent {
  FavoriteRequested(this.item);
  final SavedItem item;
}

class DeleteRequested extends SavedItemsEvent {
  DeleteRequested(this.item);
  final SavedItem item;
}

class PreviewRetryRequested extends SavedItemsEvent {
  PreviewRetryRequested(this.item);
  final SavedItem item;
}

class SavedItemsState extends Equatable {
  const SavedItemsState({
    this.items = const [],
    this.loading = true,
    this.filter = DateFilter.all,
    this.query = '',
    this.message,
    this.notice = 0,
  });
  final List<SavedItem> items;
  final bool loading;
  final DateFilter filter;
  final String query;
  final String? message;
  final int notice;
  List<SavedItem> visible(DateTime now, {bool search = false}) => items
      .where(
        (item) =>
            DateHistory.includes(item.createdAt, filter, now) &&
            (!search || item.matches(query)),
      )
      .toList();
  SavedItemsState copy({
    List<SavedItem>? items,
    bool? loading,
    DateFilter? filter,
    String? query,
    String? message,
  }) => SavedItemsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    filter: filter ?? this.filter,
    query: query ?? this.query,
    message: message,
    notice: message == null ? notice : notice + 1,
  );
  @override
  List<Object?> get props => [items, loading, filter, query, message, notice];
}

class SavedItemsBloc extends Bloc<SavedItemsEvent, SavedItemsState> {
  SavedItemsBloc(this.repository, this.shares, this.telemetry)
    : super(const SavedItemsState()) {
    on<ItemsStarted>((event, emit) async {
      if (event.loadMore) loadLimit += 100;
      await _subscription?.cancel();
      _subscription = repository
          .watch(limit: loadLimit)
          .listen(
            (items) => add(ItemsReceived(items)),
            onError: (Object e, StackTrace s) {
              unawaited(telemetry.failure('load_items', e, s));
              add(
                ItemsFailed(
                  'Could not load saved items. Check your connection or retry.',
                ),
              );
            },
          );
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
    on<ItemsReceived>(
      (event, emit) => emit(
        state.copy(items: List.unmodifiable(event.items), loading: false),
      ),
    );
    on<ItemsFailed>((event, emit) {
      // Allow retained inbox entries to be retried after an eventual rejection.
      _handledShares.clear();
      emit(state.copy(loading: false, message: event.message));
    });
    on<ShareReceived>((event, emit) async {
      final share = event.share;
      if (_handledShares.contains(share.id) || !_inFlight.add(share.id)) return;
      String? normalized;
      try {
        unawaited(telemetry.event('share_received'));
        final uri = UrlParser.parse(share.text);
        normalized = uri.toString();
        if (!_acceptedShares.contains(share.id) &&
            !_duplicates.accept(normalized, share.receivedAt)) {
          await shares.acknowledge(share.id);
          _handledShares.add(share.id);
          emit(state.copy(message: 'Already saved just now.'));
          return;
        }
        _acceptedShares.add(share.id);
        final confirmed = await repository.save(share.id, uri, share.text);
        if (confirmed) {
          await shares.acknowledge(share.id);
          _handledShares.add(share.id);
        }
        unawaited(telemetry.event('item_saved'));
        emit(
          state.copy(message: 'Saved. Offline changes sync when connected.'),
        );
      } on FormatException {
        try {
          await shares.acknowledge(share.id);
          _handledShares.add(share.id);
        } catch (e, s) {
          unawaited(telemetry.failure('invalid_share_ack', e, s));
        }
        emit(
          state.copy(
            message: 'Share text containing a valid http or https link.',
          ),
        );
      } catch (e, s) {
        _acceptedShares.remove(share.id);
        if (normalized != null) _duplicates.forget(normalized);
        unawaited(telemetry.failure('receive_share', e, s));
        emit(
          state.copy(
            message:
                'Could not save yet. Your share is kept; tap refresh to retry.',
          ),
        );
      } finally {
        _inFlight.remove(share.id);
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
    on<FilterChanged>((event, emit) {
      emit(state.copy(filter: event.filter));
      unawaited(telemetry.event('date_filter_used'));
    });
    on<SearchChanged>((event, emit) {
      if (state.query.isEmpty && event.query.isNotEmpty) {
        unawaited(telemetry.event('search_used'));
      }
      emit(state.copy(query: event.query));
    });
    on<FavoriteRequested>((event, emit) async {
      if (!_changingItems.add(event.item.id)) return;
      try {
        await repository.favorite(event.item);
        unawaited(telemetry.event('item_favorited'));
      } catch (e, s) {
        unawaited(telemetry.failure('favorite', e, s));
        emit(state.copy(message: 'Could not update favorite. Try again.'));
      } finally {
        _changingItems.remove(event.item.id);
      }
    });
    on<DeleteRequested>((event, emit) async {
      if (!_changingItems.add(event.item.id)) return;
      try {
        await repository.delete(event.item.id);
        await shares.acknowledge(event.item.id);
        unawaited(telemetry.event('item_deleted'));
      } catch (e, s) {
        unawaited(telemetry.failure('delete', e, s));
        emit(state.copy(message: 'Could not delete item. Try again.'));
      } finally {
        _changingItems.remove(event.item.id);
      }
    });
    on<PreviewRetryRequested>((event, emit) async {
      if (!_changingItems.add('preview:${event.item.id}')) return;
      try {
        final resolved = await repository.retryMetadata(event.item);
        emit(
          state.copy(
            message: resolved
                ? 'Preview updated.'
                : 'No public preview was available for this link.',
          ),
        );
      } catch (e, s) {
        unawaited(telemetry.failure('metadata_retry', e, s));
        emit(state.copy(message: 'Could not refresh this preview. Try again.'));
      } finally {
        _changingItems.remove('preview:${event.item.id}');
      }
    });
    if (repository is FirestoreSavedItemsRepository) {
      _failures = (repository as FirestoreSavedItemsRepository).failures.listen(
        (message) => add(ItemsFailed(message)),
      );
    }
  }
  final SavedItemsRepository repository;
  int loadLimit = 100;
  final ShareService shares;
  final Telemetry telemetry;
  final _duplicates = DuplicateGuard();
  final _inFlight = <String>{};
  final _acceptedShares = <String>{};
  // Each BLoC belongs to one UID; duplicate state never crosses accounts.
  final _handledShares = <String>{};
  final _changingItems = <String>{};
  StreamSubscription<List<SavedItem>>? _subscription;
  StreamSubscription<String>? _failures;
  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _failures?.cancel();
    if (repository is FirestoreSavedItemsRepository) {
      await (repository as FirestoreSavedItemsRepository).dispose();
    }
    return super.close();
  }
}
