import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/link_metadata_service.dart';
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
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  RepeatType _repeat = RepeatType.never;
  int _customDays = 2;
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.item == null ? 'Save this find' : 'Edit saved find',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('A reminder is optional. Your find is saved either way.'),
          const SizedBox(height: 20),
          TextField(
            controller: _content,
            minLines: 1,
            maxLines: 4,
            enabled: widget.item == null,
            decoration: InputDecoration(
              labelText: 'URL or text',
              suffixIcon: _url == null
                  ? null
                  : IconButton(
                      tooltip: 'Load preview',
                      onPressed: _previewing ? null : _preview,
                      icon: _previewing
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                    ),
            ),
            onSubmitted: (_) => unawaited(_preview()),
            onChanged: (_) => setState(() {}),
          ),
          if (_previewSite != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: _previewImage == null
                    ? const Icon(Icons.link_rounded)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          _previewImage!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.link_rounded),
                        ),
                      ),
                title: Text(
                  _title.text.trim().isEmpty ? 'Preview' : _title.text,
                ),
                subtitle: Text(_previewSite!),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tag,
            decoration: const InputDecoration(labelText: 'Tag (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me'),
            subtitle: const Text('Off by default'),
            value: _remind,
            onChanged: (value) => setState(() => _remind = value),
          ),
          if (_remind) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (value != null) setState(() => _date = value);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      MaterialLocalizations.of(context).formatShortDate(_date),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final value = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (value != null) setState(() => _time = value);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RepeatType>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: RepeatType.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_label(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _repeat = value ?? RepeatType.never),
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
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _content.text.trim().isEmpty || _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save find'),
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
