import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/link_metadata_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reminders/data/reminder_service.dart';
import '../../../reminders/domain/reminder.dart';
import '../../domain/saved_item.dart';
import '../bloc/saved_items_bloc.dart';

class SaveFindSheet extends StatefulWidget {
  const SaveFindSheet({super.key, this.item});
  final SavedItem? item;

  @override
  State<SaveFindSheet> createState() => _SaveFindSheetState();
}

class _SaveFindSheetState extends State<SaveFindSheet> {
  late final TextEditingController _content;
  late final TextEditingController _title;
  late final TextEditingController _tag;
  late final TextEditingController _notes;
  bool _remind = false, _saving = false, _previewing = false;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  RepeatType _repeat = RepeatType.never;
  int _customDays = 2;
  String _snoozeChoice = '10 min';
  String? _previewSite, _previewImage;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _content = TextEditingController(
      text: item?.url.isNotEmpty == true ? item!.url : item?.sharedText,
    );
    _title = TextEditingController(text: item?.title ?? '');
    _tag = TextEditingController(text: item?.tag ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _remind = item?.hasReminder ?? false;
    _repeat = item?.repeatType ?? RepeatType.never;
    _customDays = item?.customIntervalDays ?? 2;
    final reminder = item?.reminderAt?.toLocal();
    if (reminder != null) {
      _date = reminder;
      _time = TimeOfDay.fromDateTime(reminder);
    }
    _previewSite = item?.displaySource;
    _previewImage = item?.thumbnailUrl;
  }

  @override
  void dispose() {
    _content.dispose();
    _title.dispose();
    _tag.dispose();
    _notes.dispose();
    super.dispose();
  }

  Uri? get _url {
    final candidate = Uri.tryParse(_content.text.trim());
    return candidate != null &&
            (candidate.scheme == 'http' || candidate.scheme == 'https') &&
            candidate.host.isNotEmpty
        ? candidate
        : null;
  }

  Future<void> _preview() async {
    final uri = _url;
    if (uri == null || _previewing) return;
    setState(() => _previewing = true);
    final service = LinkMetadataService();
    try {
      final metadata = await service.fetch(uri);
      if (!mounted) return;
      if (_title.text.trim().isEmpty && metadata?.title != null) {
        _title.text = metadata!.title!;
      }
      setState(() {
        _previewSite = metadata?.siteName ?? metadata?.domain ?? uri.host;
        _previewImage = metadata?.thumbnailUrl;
      });
    } finally {
      service.close();
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final date = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final draft = SavedItemDraft(
      content: _content.text.trim(),
      url: _url,
      title: _nullIfEmpty(_title.text),
      tag: _nullIfEmpty(_tag.text),
      notes: _nullIfEmpty(_notes.text),
      reminderAt: _remind ? date : null,
      repeatType: _remind ? _repeat : RepeatType.never,
      customIntervalDays: _remind && _repeat == RepeatType.custom
          ? _customDays
          : null,
    );
    if (_remind) {
      await context.read<ReminderService>().requestPermission();
      if (!mounted) return;
    }
    final completer = Completer<void>();
    final bloc = context.read<SavedItemsBloc>();
    if (widget.item case final item?) {
      bloc.add(UpdateRequested(item, draft, completer));
    } else {
      final created = Completer<String>();
      bloc.add(CreateRequested(draft, created));
      unawaited(
        created.future.then(
          (_) => completer.complete(),
          onError: completer.completeError,
        ),
      );
    }
    try {
      await completer.future;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    final formatted = MaterialLocalizations.of(context).formatMediumDate(date);
    if (diff == 0) return 'Today, $formatted';
    if (diff == 1) return 'Tomorrow, $formatted';
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 24),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
              const Spacer(),
              if (_remind)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _remind = false);
                          unawaited(_save());
                        },
                  child: Text(
                    'Save without reminder',
                    style: TextStyle(
                      color: dark ? AppTheme.mint : AppTheme.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.item == null ? 'Save this find' : 'Edit saved find',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add reminder (optional) and keep it for later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (_previewSite != null ||
              _previewImage != null ||
              widget.item != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF14241F) : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF263A33)
                      : const Color(0xFFE1EEE8),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: _previewImage != null
                          ? Image.network(
                              _previewImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: dark
                                    ? const Color(0xFF1E382D)
                                    : AppTheme.paleMint,
                                child: Icon(
                                  Icons.link_rounded,
                                  color: dark ? AppTheme.mint : AppTheme.brand,
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: dark
                                  ? const Color(0xFF1E382D)
                                  : AppTheme.paleMint,
                              child: Icon(
                                Icons.link_rounded,
                                color: dark ? AppTheme.mint : AppTheme.brand,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title.text.trim().isNotEmpty
                              ? _title.text.trim()
                              : widget.item?.displayTitle ?? 'Saved Link',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.language_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _previewSite ??
                                    widget.item?.displayDomain ??
                                    _url?.host ??
                                    '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit link',
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.item == null) ...[
            TextField(
              controller: _content,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'URL or text',
                hintText: 'https://...',
                suffixIcon: _url == null
                    ? null
                    : IconButton(
                        tooltip: 'Load preview',
                        onPressed: _previewing ? null : _preview,
                        icon: _previewing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                      ),
              ),
              onSubmitted: (_) => unawaited(_preview()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Title',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: 'Add a title...'),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF14241F) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: dark ? const Color(0xFF263A33) : const Color(0xFFE1EEE8),
              ),
            ),
            child: SwitchListTile.adaptive(
              secondary: CircleAvatar(
                radius: 20,
                backgroundColor: dark
                    ? const Color(0xFF1B382D)
                    : AppTheme.paleMint,
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 20,
                  color: dark ? AppTheme.mint : AppTheme.brand,
                ),
              ),
              title: const Text(
                'Remind me (optional)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Get notified when it’s time to revisit'),
              value: _remind,
              onChanged: (value) => setState(() => _remind = value),
            ),
          ),
          if (_remind) ...[
            const SizedBox(height: 16),
            Text(
              'Date',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (value != null) setState(() => _date = value);
              },
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: dark ? AppTheme.mint : AppTheme.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatFriendlyDate(_date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Time',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () async {
                final value = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (value != null) setState(() => _time = value);
              },
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: dark ? AppTheme.mint : AppTheme.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _time.format(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Repeat',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: RepeatType.values
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_label(value)),
                          selected: _repeat == value,
                          onSelected: (_) => setState(() => _repeat = value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (_repeat == RepeatType.custom) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _customDays,
                decoration: const InputDecoration(labelText: 'Repeat every'),
                items: const [2, 3, 5, 7, 14, 30]
                    .map(
                      (days) => DropdownMenuItem(
                        value: days,
                        child: Text('$days days'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _customDays = value ?? 2),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Snooze (when reminded)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['10 min', '1 hour', 'Tonight', 'Tomorrow', 'Custom']
                    .map(
                      (choice) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(choice),
                          selected: _snoozeChoice == choice,
                          onSelected: (_) =>
                              setState(() => _snoozeChoice = choice),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Notes (optional)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a note...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _content.text.trim().isEmpty || _saving ? null : _save,
            icon: const Icon(Icons.bookmark_rounded),
            label: Text(_saving ? 'Saving…' : 'Save find'),
          ),
        ],
      ),
    );
  }

  static String _label(RepeatType type) => switch (type) {
    RepeatType.never => 'Never',
    RepeatType.daily => 'Daily',
    RepeatType.weekly => 'Weekly',
    RepeatType.monthly => 'Monthly',
    RepeatType.custom => 'Custom',
  };
}
