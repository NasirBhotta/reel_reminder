import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/services/telemetry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/content.dart';
import '../../../profile/presentation/profile_page.dart';
import '../../domain/saved_item.dart';
import '../bloc/saved_items_bloc.dart';
import 'saved_item_details_page.dart';
import '../widgets/saved_item_card.dart';
import '../widgets/save_find_sheet.dart';
import '../../../reminders/data/reminder_service.dart';
import '../../../reminders/domain/reminder.dart';

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
  StreamSubscription<ReminderResponse>? _reminderActions;
  final _search = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.shares.listen(_drain);
    unawaited(_drain());
    _scheduleDateRefresh();
    _reminderActions = context.read<ReminderService>().responses.listen(
      _handleReminderResponse,
    );
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = context.read<ReminderService>().takePendingResponse();
      if (pending != null) unawaited(_handleReminderResponse(pending));
    });
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
    _searchFocusNode.dispose();
    _clock?.cancel();
    _reminderActions?.cancel();
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

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showSave([SavedItem? item]) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SavedItemsBloc>(),
        child: SaveFindSheet(item: item),
      ),
    );
  }

  Future<void> _handleReminderResponse(ReminderResponse response) async {
    final bloc = context.read<SavedItemsBloc>();
    final matches = bloc.state.items.where(
      (item) => item.id == response.itemId,
    );
    if (matches.isEmpty) return;
    final item = matches.first;
    switch (response.action) {
      case ReminderAction.open:
        await _action(item, ItemAction.open);
      case ReminderAction.snooze:
        await _snoozeReminder(item);
      case ReminderAction.done:
        await _doneReminder(item);
    }
  }

  Future<void> _doneReminder(SavedItem item) async {
    final bloc = context.read<SavedItemsBloc>();
    final reminders = context.read<ReminderService>();
    final next = ReminderCalculator.nextOccurrence(
      scheduled: item.reminderAt ?? DateTime.now(),
      repeat: item.repeatType,
      after: DateTime.now(),
      customIntervalDays: item.customIntervalDays,
    );
    if (next == null) {
      await _removeReminder(item);
      if (mounted) _message('Reminder completed.');
      return;
    }
    final completer = Completer<void>();
    bloc.add(
      UpdateRequested(
        item,
        SavedItemDraft(
          content: item.url.isNotEmpty ? item.url : item.sharedText ?? '',
          url: Uri.tryParse(item.url),
          title: item.title,
          tag: item.tag,
          notes: item.notes,
          reminderAt: next,
          repeatType: item.repeatType,
          customIntervalDays: item.customIntervalDays,
        ),
        completer,
      ),
    );
    await completer.future;
    await reminders.schedule(
      itemId: item.id,
      title: item.displayTitle,
      at: next,
      repeat: item.repeatType,
      customIntervalDays: item.customIntervalDays,
    );
    if (mounted) _message('Reminder advanced to next repeat occurrence.');
  }

  Future<void> _snoozeReminder(SavedItem item) async {
    final reminders = context.read<ReminderService>();
    final duration = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Snooze 10 minutes'),
              onTap: () => Navigator.pop(context, const Duration(minutes: 10)),
            ),
            ListTile(
              title: const Text('Snooze 1 hour'),
              onTap: () => Navigator.pop(context, const Duration(hours: 1)),
            ),
            ListTile(
              title: const Text('Tonight (8 PM)'),
              onTap: () => Navigator.pop(
                context,
                ReminderCalculator.tonight(
                  DateTime.now(),
                ).difference(DateTime.now()),
              ),
            ),
            ListTile(
              title: const Text('Tomorrow (9 AM)'),
              onTap: () => Navigator.pop(
                context,
                ReminderCalculator.tomorrow(
                  DateTime.now(),
                ).difference(DateTime.now()),
              ),
            ),
            ListTile(
              title: const Text('Custom snooze…'),
              onTap: () => Navigator.pop(context, Duration.zero),
            ),
          ],
        ),
      ),
    );
    if (duration == null || !mounted) return;
    if (duration == Duration.zero) {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (time == null) return;
      final customDuration = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).difference(now);
      if (customDuration.isNegative) return;
      await reminders.snooze(
        itemId: item.id,
        title: item.displayTitle,
        until: DateTime.now().add(customDuration),
      );
      if (mounted) _message('Reminder snoozed.');
      return;
    }
    await reminders.snooze(
      itemId: item.id,
      title: item.displayTitle,
      until: DateTime.now().add(duration),
    );
    if (mounted) _message('Reminder snoozed.');
  }

  Future<void> _removeReminder(SavedItem item) async {
    final completer = Completer<void>();
    context.read<SavedItemsBloc>().add(
      UpdateRequested(
        item,
        SavedItemDraft(
          content: item.url.isNotEmpty ? item.url : item.sharedText ?? '',
          url: Uri.tryParse(item.url),
          title: item.title,
          tag: item.tag,
          notes: item.notes,
        ),
        completer,
      ),
    );
    await completer.future;
  }

  Future<void> _action(SavedItem item, ItemAction action) async {
    final bloc = context.read<SavedItemsBloc>();
    try {
      switch (action) {
        case ItemAction.details:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: SavedItemDetailsPage(
                  itemId: item.id,
                  onAction: _action,
                  onEdit: _showSave,
                  onRemoveReminder: _removeReminder,
                ),
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
          await Clipboard.setData(
            ClipboardData(
              text: item.hasLink ? item.url : item.sharedText ?? '',
            ),
          );
          if (mounted) _message(item.hasLink ? 'Link copied' : 'Text copied');
        case ItemAction.share:
          await widget.shares.share(
            item.hasLink ? item.url : item.sharedText ?? item.displayTitle,
          );
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return BlocConsumer<SavedItemsBloc, SavedItemsState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        if (state.message != null) _message(state.message!);
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(toolbarHeight: 0),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  label: 'Home',
                  icon: _tab == 0 ? Icons.home_rounded : Icons.home_outlined,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _NavAddButton(onTap: _showSave),
                _NavBarItem(
                  label: 'Profile',
                  icon: _tab == 1
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
        ),
        body: _tab == 1
            ? ProfilePage(
                themeMode: widget.themeMode,
                onThemeChanged: widget.onThemeChanged,
              )
            : SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your saved finds',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Links, products and more — all in one place.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dark
                                    ? const Color(0xFF30483F)
                                    : const Color(0xFFD9E9E1),
                              ),
                            ),
                            child: IconButton(
                              tooltip: 'Search your finds',
                              onPressed: () {
                                if (!_searchFocusNode.hasFocus) {
                                  _searchFocusNode.requestFocus();
                                } else {
                                  context.read<SavedItemsBloc>().add(
                                    ItemsStarted(),
                                  );
                                  unawaited(_drain());
                                }
                              },
                              icon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF14241F)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color:
                                      (_searchFocusNode.hasFocus ||
                                          _search.text.isNotEmpty)
                                      ? (dark ? AppTheme.mint : AppTheme.brand)
                                      : (dark
                                            ? const Color(0xFF30483F)
                                            : const Color(0xFFD9E9E1)),
                                  width:
                                      (_searchFocusNode.hasFocus ||
                                          _search.text.isNotEmpty)
                                      ? 1.8
                                      : 1.0,
                                ),
                              ),
                              child: TextField(
                                controller: _search,
                                focusNode: _searchFocusNode,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color:
                                        (_searchFocusNode.hasFocus ||
                                            _search.text.isNotEmpty)
                                        ? (dark
                                              ? AppTheme.mint
                                              : AppTheme.brand)
                                        : theme.colorScheme.outline,
                                  ),
                                  hintText: 'Search your finds...',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.outline,
                                  ),
                                  suffixIcon: _search.text.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            _search.clear();
                                            setState(() {});
                                            context.read<SavedItemsBloc>().add(
                                              SearchChanged(''),
                                            );
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        )
                                      : null,
                                ),
                                onChanged: (query) {
                                  setState(() {});
                                  context.read<SavedItemsBloc>().add(
                                    SearchChanged(query),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_searchFocusNode.hasFocus ||
                              _search.text.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                _search.clear();
                                _searchFocusNode.unfocus();
                                context.read<SavedItemsBloc>().add(
                                  SearchChanged(''),
                                );
                                setState(() {});
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: dark ? AppTheme.mint : AppTheme.brand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children:
                            [
                              DateFilter.today,
                              DateFilter.yesterday,
                              DateFilter.week,
                              DateFilter.month,
                              DateFilter.all,
                            ].map((filter) {
                              final isSelected = state.filter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(switch (filter) {
                                    DateFilter.today => 'Today',
                                    DateFilter.yesterday => 'Yesterday',
                                    DateFilter.week => 'This Week',
                                    DateFilter.month => 'This Month',
                                    DateFilter.all => 'All',
                                  }),
                                  selected: isSelected,
                                  onSelected: (_) => context
                                      .read<SavedItemsBloc>()
                                      .add(FilterChanged(filter)),
                                ),
                              );
                            }).toList(),
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
                    Expanded(
                      child: NotificationListener<OverscrollNotification>(
                        onNotification: (notification) {
                          if (notification.overscroll < -8 &&
                              !_searchFocusNode.hasFocus) {
                            _searchFocusNode.requestFocus();
                          }
                          return false;
                        },
                        child: _timeline(state),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _timeline(SavedItemsState state) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final isSearching = _search.text.trim().isNotEmpty;
    final items = state.visible(now, search: isSearching);

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
                    : isSearching
                    ? 'No search results'
                    : 'No finds in this date range',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                state.items.isEmpty
                    ? 'Open TikTok, Instagram, YouTube, or another app → tap Share → choose Reel Reminder.'
                    : isSearching
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

    final groupCounts = <String, int>{};
    for (final item in items) {
      final group = DateHistory.group(item.createdAt, now);
      groupCounts[group] = (groupCounts[group] ?? 0) + 1;
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<SavedItemsBloc>().add(ItemsStarted());
        await _drain();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final group = DateHistory.group(item.createdAt, now);
          final header =
              index == 0 ||
              DateHistory.group(items[index - 1].createdAt, now) != group;
          final count = groupCounts[group] ?? 1;

          return Column(
            key: ValueKey(item.id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        group,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '$count items',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final activeColor = dark ? AppTheme.mint : AppTheme.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? (dark ? const Color(0xFF19382B) : AppTheme.paleMint)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                icon,
                color: selected
                    ? activeColor
                    : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? activeColor
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavAddButton extends StatelessWidget {
  const _NavAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final buttonColor = dark ? AppTheme.mint : AppTheme.brand;
    final iconColor = dark ? AppTheme.ink : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.add_rounded, color: iconColor, size: 24),
            ),
            const SizedBox(height: 3),
            Text(
              'Add',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
