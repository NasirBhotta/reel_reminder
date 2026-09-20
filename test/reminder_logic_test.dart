import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_reminder/features/reminders/domain/reminder.dart';
import 'package:reel_reminder/features/saved_items/domain/saved_item.dart';

void main() {
  final monday = DateTime(2026, 9, 21, 20);

  test('save without reminder remains independent', () {
    const draft = SavedItemDraft(content: 'A useful note');
    expect(draft.hasReminder, isFalse);
    expect(draft.repeatType, RepeatType.never);
  });

  test('one-time reminder has no occurrence after it fires', () {
    expect(
      ReminderCalculator.nextOccurrence(
        scheduled: monday,
        repeat: RepeatType.never,
        after: monday,
      ),
      isNull,
    );
  });

  test('daily Done advances to original time next day', () {
    final next = ReminderCalculator.nextOccurrence(
      scheduled: monday,
      repeat: RepeatType.daily,
      after: monday.add(const Duration(minutes: 1)),
    );
    expect(next, DateTime(2026, 9, 22, 20));
  });

  test('weekly Done keeps next weekly occurrence', () {
    final next = ReminderCalculator.nextOccurrence(
      scheduled: monday,
      repeat: RepeatType.weekly,
      after: monday,
    );
    expect(next, DateTime(2026, 9, 28, 20));
  });

  test('monthly repeat clamps to final day of short month', () {
    final january31 = DateTime(2027, 1, 31, 9, 30);
    final next = ReminderCalculator.nextOccurrence(
      scheduled: january31,
      repeat: RepeatType.monthly,
      after: january31,
    );
    expect(next, DateTime(2027, 2, 28, 9, 30));
  });

  test('custom repeat uses configured day interval', () {
    final next = ReminderCalculator.nextOccurrence(
      scheduled: monday,
      repeat: RepeatType.custom,
      customIntervalDays: 3,
      after: monday,
    );
    expect(next, DateTime(2026, 9, 24, 20));
  });

  test('snooze 10 minutes and one hour', () {
    expect(
      ReminderCalculator.snooze(monday, const Duration(minutes: 10)),
      DateTime(2026, 9, 21, 20, 10),
    );
    expect(
      ReminderCalculator.snooze(monday, const Duration(hours: 1)),
      DateTime(2026, 9, 21, 21),
    );
  });

  test('snoozing occurrence does not shift weekly base schedule', () {
    final snoozed = ReminderCalculator.snooze(monday, const Duration(hours: 1));
    final nextBase = ReminderCalculator.nextOccurrence(
      scheduled: monday,
      repeat: RepeatType.weekly,
      after: snoozed,
    );
    expect(snoozed, DateTime(2026, 9, 21, 21));
    expect(nextBase, DateTime(2026, 9, 28, 20));
  });

  test('reminder can be edited or removed without deleting content', () {
    final edited = SavedItemDraft(
      content: 'https://example.com',
      reminderAt: monday,
      repeatType: RepeatType.weekly,
    );
    const removed = SavedItemDraft(content: 'https://example.com');
    expect(edited.hasReminder, isTrue);
    expect(removed.hasReminder, isFalse);
    expect(removed.content, edited.content);
  });

  test('old Firestore document defaults to no reminder', () {
    final time = Timestamp.fromDate(monday);
    final item = SavedItem.fromData(
      id: 'legacy',
      data: {
        'userId': 'u',
        'url': 'https://example.com',
        'platform': 'website',
        'createdAt': time,
        'updatedAt': time,
        'clientCreatedAt': time,
        'isFavorite': false,
      },
    );
    expect(item.hasReminder, isFalse);
    expect(item.repeatType, RepeatType.never);
    expect(item.reminderAt, isNull);
  });
}
