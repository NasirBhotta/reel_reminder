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
  Timer? _clock;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.shares.listen(_drain);
    unawaited(_drain());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
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
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final pending = await widget.shares.pending(widget.uid);
      if (!mounted) return;
      for (final share in pending) {
        context.read<SavedItemsBloc>().add(ShareReceived(share));
      }
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
        case ItemAction.open:
          if (!await launchUrl(
            Uri.parse(item.url),
            mode: LaunchMode.externalApplication,
          )) {
            throw StateError('No link handler');
          }
          unawaited(widget.telemetry.event('item_opened'));
        case ItemAction.copy:
          await Clipboard.setData(ClipboardData(text: item.url));
          if (mounted) _message('Link copied');
        case ItemAction.share:
          await widget.shares.share(item.url);
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
        _message('Could not complete that action. Please try again.');
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
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Title, link, text, or platform',
                      ),
                      onChanged: (query) => context.read<SavedItemsBloc>().add(
                        SearchChanged(query),
                      ),
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
                      '${state.items.length} loaded · search and filters use loaded items',
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
                    : 'No finds match yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                state.items.isEmpty
                    ? 'In YouTube, Instagram, or your browser, tap Share and choose Reel Reminder.'
                    : 'Try another date filter or search term.',
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
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final group = DateHistory.group(item.createdAt, now);
          final header =
              index == 0 ||
              DateHistory.group(items[index - 1].createdAt, now) != group;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                    group,
                    style: Theme.of(context).textTheme.titleSmall,
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
