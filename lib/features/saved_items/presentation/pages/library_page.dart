import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/services/telemetry.dart';
import '../../../../core/utils/content.dart';
import '../../../profile/presentation/profile_page.dart';
import '../../domain/saved_item.dart';
import '../bloc/saved_items_bloc.dart';
import 'saved_item_details_page.dart';
import '../widgets/saved_item_card.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.uid,
    required this.shares,
    required this.telemetry,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final String uid;
  final ShareService shares;
  final Telemetry telemetry;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  int _tab = 0;
  bool _draining = false;
  bool _drainAgain = false;
  Timer? _clock;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.shares.listen(_drain);
    unawaited(_drain());
    _scheduleDateRefresh();
  }

  void _scheduleDateRefresh() {
    _clock?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _clock = Timer(midnight.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleDateRefresh();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _clock?.cancel();
    widget.shares.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleDateRefresh();
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        final pending = await widget.shares.pending(widget.uid);
        if (!mounted) return;
        for (final share in pending) {
          context.read<SavedItemsBloc>().add(ShareReceived(share));
        }
      } while (_drainAgain && mounted);
    } on MissingPluginException {
      /* iOS share extension is a future platform adapter. */
    } catch (e, s) {
      unawaited(widget.telemetry.failure('share_inbox', e, s));
      if (mounted) {
        _message('Could not read shared links. Tap refresh to retry.');
      }
    } finally {
      _draining = false;
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  Future<void> _action(SavedItem item, ItemAction action) async {
    final bloc = context.read<SavedItemsBloc>();
    try {
      switch (action) {
        case ItemAction.details:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: SavedItemDetailsPage(itemId: item.id, onAction: _action),
              ),
            ),
          );
        case ItemAction.open:
          final uri = UrlParser.parse(item.url);
          var opened = false;
          try {
            opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } on PlatformException {
            // A broken native handler can still leave a browser available.
          }
          if (!opened) {
            opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          }
          if (!opened) {
            throw StateError('No link handler');
          }
          unawaited(widget.telemetry.event('item_opened'));
        case ItemAction.copy:
          await Clipboard.setData(ClipboardData(text: item.url));
          if (mounted) _message('Link copied');
        case ItemAction.share:
          await widget.shares.share(item.url);
        case ItemAction.retryPreview:
          bloc.add(PreviewRetryRequested(item));
        case ItemAction.favorite:
          bloc.add(FavoriteRequested(item));
        case ItemAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete this saved item?'),
              content: const Text('This removes it from your library.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) bloc.add(DeleteRequested(item));
      }
    } catch (e, s) {
      unawaited(widget.telemetry.failure('item_action', e, s));
      if (mounted) {
        _message(
          action == ItemAction.open
              ? 'Could not open this link. Try copying it into your browser.'
              : 'Could not complete that action. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SavedItemsBloc, SavedItemsState>(
    listenWhen: (previous, current) => previous.notice != current.notice,
    listener: (context, state) {
      if (state.message != null) _message(state.message!);
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: Text(
          ['Your saved finds', 'Search your finds', 'Your account'][_tab],
        ),
        actions: [
          if (_tab != 2)
            IconButton(
              tooltip: 'Refresh and retry shares',
              onPressed: () {
                context.read<SavedItemsBloc>().add(ItemsStarted());
                unawaited(_drain());
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
      body: _tab == 2
          ? ProfilePage(
              themeMode: widget.themeMode,
              onThemeChanged: widget.onThemeChanged,
            )
          : Column(
              children: [
                if (_tab == 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search title, text, source, or link',
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                  context.read<SavedItemsBloc>().add(
                                    SearchChanged(''),
                                  );
                                },
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                      onChanged: (query) {
                        setState(() {});
                        context.read<SavedItemsBloc>().add(
                          SearchChanged(query),
                        );
                      },
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: DateFilter.values
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(switch (filter) {
                                DateFilter.today => 'Today',
                                DateFilter.yesterday => 'Yesterday',
                                DateFilter.week => 'This Week',
                                DateFilter.month => 'This Month',
                                DateFilter.all => 'All',
                              }),
                              selected: state.filter == filter,
                              onSelected: (_) => context
                                  .read<SavedItemsBloc>()
                                  .add(FilterChanged(filter)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tab == 1 && state.query.trim().isNotEmpty
                          ? '${state.visible(DateTime.now(), search: true).length} results in loaded items'
                          : '${state.items.length} loaded · filters use loaded items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                if (state.items.length >=
                    context.read<SavedItemsBloc>().loadLimit)
                  TextButton(
                    onPressed: () => context.read<SavedItemsBloc>().add(
                      ItemsStarted(loadMore: true),
                    ),
                    child: const Text('Load older finds'),
                  ),
                Expanded(child: _timeline(state)),
              ],
            ),
    ),
  );
  Widget _timeline(SavedItemsState state) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final items = state.visible(now, search: _tab == 1);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_add_outlined, size: 64),
              const SizedBox(height: 20),
              Text(
                state.items.isEmpty
                    ? 'Your next good find belongs here.'
                    : _tab == 1 && state.query.trim().isNotEmpty
                    ? 'No search results'
                    : 'No finds in this date range',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                state.items.isEmpty
                    ? 'Open TikTok, Instagram, YouTube, or another app → tap Share → choose Reel Reminder.'
                    : _tab == 1 && state.query.trim().isNotEmpty
                    ? 'Try a shorter title, source, or link.'
                    : 'Try another date filter.',
                textAlign: TextAlign.center,
              ),
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(state.message!),
                ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SavedItemsBloc>().add(ItemsStarted());
        await _drain();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final group = DateHistory.group(item.createdAt, now);
          final header =
              index == 0 ||
              DateHistory.group(items[index - 1].createdAt, now) != group;
          return Column(
            key: ValueKey(item.id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Text(
                    group,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SavedItemCard(
                item: item,
                onAction: (action) => unawaited(_action(item, action)),
              ),
            ],
          );
        },
      ),
    );
  }
}
