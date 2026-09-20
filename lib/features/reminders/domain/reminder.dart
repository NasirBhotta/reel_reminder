enum RepeatType { never, daily, weekly, monthly, custom }

RepeatType repeatTypeFrom(Object? value) => RepeatType.values.firstWhere(
  (type) => type.name == value,
  orElse: () => RepeatType.never,
);

abstract final class ReminderCalculator {
  static DateTime? nextOccurrence({
    required DateTime scheduled,
    required RepeatType repeat,
    required DateTime after,
    int? customIntervalDays,
  }) {
    if (repeat == RepeatType.never) {
      return scheduled.isAfter(after) ? scheduled : null;
    }
    var next = scheduled;
    while (!next.isAfter(after)) {
      next = switch (repeat) {
        RepeatType.daily => next.add(const Duration(days: 1)),
        RepeatType.weekly => next.add(const Duration(days: 7)),
        RepeatType.monthly => _addMonth(next),
        RepeatType.custom => next.add(Duration(days: customIntervalDays ?? 1)),
        RepeatType.never => next,
      };
    }
    return next;
  }

  static DateTime _addMonth(DateTime value) {
    final targetMonth = value.month == 12 ? 1 : value.month + 1;
    final targetYear = value.month == 12 ? value.year + 1 : value.year;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(
      targetYear,
      targetMonth,
      value.day.clamp(1, lastDay),
      value.hour,
      value.minute,
    );
  }

  static DateTime snooze(DateTime now, Duration duration) => now.add(duration);

  static DateTime tonight(DateTime now) {
    final tonight = DateTime(now.year, now.month, now.day, 20);
    return tonight.isAfter(now)
        ? tonight
        : tonight.add(const Duration(days: 1));
  }

  static DateTime tomorrow(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1, 9);
}
