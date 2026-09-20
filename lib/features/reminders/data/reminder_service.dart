import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../domain/reminder.dart';

enum ReminderAction { open, snooze, done }

class ReminderResponse {
  const ReminderResponse(this.itemId, this.action);
  final String itemId;
  final ReminderAction action;
}

class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _responses = StreamController<ReminderResponse>.broadcast();
  ReminderResponse? _pendingResponse;
  Stream<ReminderResponse> get responses => _responses.stream;
  ReminderResponse? takePendingResponse() {
    final value = _pendingResponse;
    _pendingResponse = null;
    return value;
  }

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // UTC is a safe fallback when the host cannot expose an IANA zone.
    }
    final actions = <DarwinNotificationAction>[
      DarwinNotificationAction.plain(
        'open',
        'Open',
        options: {DarwinNotificationActionOption.foreground},
      ),
      DarwinNotificationAction.plain(
        'snooze',
        'Snooze',
        options: {DarwinNotificationActionOption.foreground},
      ),
      DarwinNotificationAction.plain(
        'done',
        'Done',
        options: {DarwinNotificationActionOption.foreground},
      ),
    ];
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          notificationCategories: [
            DarwinNotificationCategory('reminder', actions: actions),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _handle,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      _handle(response, pending: true);
    }
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
  }

  Future<void> schedule({
    required String itemId,
    required String title,
    required DateTime at,
    required RepeatType repeat,
    int? customIntervalDays,
  }) async {
    await cancel(itemId);
    final next = ReminderCalculator.nextOccurrence(
      scheduled: at,
      repeat: repeat,
      after: DateTime.now(),
      customIntervalDays: customIntervalDays,
    );
    if (next == null) return;
    final scheduleMode = await _scheduleMode();
    await _plugin.zonedSchedule(
      id: _id(itemId),
      title: title,
      body: 'A find you wanted to revisit.',
      scheduledDate: tz.TZDateTime.from(next, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'saved_find_reminders',
          'Saved find reminders',
          channelDescription: 'Optional reminders for your saved finds',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('open', 'OPEN', showsUserInterface: true),
            AndroidNotificationAction(
              'snooze',
              'SNOOZE',
              showsUserInterface: true,
            ),
            AndroidNotificationAction('done', 'DONE', showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'reminder'),
      ),
      androidScheduleMode: scheduleMode,
      payload: jsonEncode({'itemId': itemId}),
      matchDateTimeComponents: switch (repeat) {
        RepeatType.daily => DateTimeComponents.time,
        RepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
        RepeatType.monthly => DateTimeComponents.dayOfMonthAndTime,
        _ => null,
      },
    );
    if (repeat == RepeatType.custom) {
      final interval = Duration(days: customIntervalDays ?? 1);
      for (var occurrence = 1; occurrence < 64; occurrence++) {
        await _plugin.zonedSchedule(
          id: _id('$itemId:custom:$occurrence'),
          title: title,
          body: 'A find you wanted to revisit.',
          scheduledDate: tz.TZDateTime.from(
            next.add(interval * occurrence),
            tz.local,
          ),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'saved_find_reminders',
              'Saved find reminders',
              channelDescription: 'Optional reminders for your saved finds',
              importance: Importance.high,
              priority: Priority.high,
              actions: [
                AndroidNotificationAction(
                  'open',
                  'OPEN',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'snooze',
                  'SNOOZE',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'done',
                  'DONE',
                  showsUserInterface: true,
                ),
              ],
            ),
            iOS: DarwinNotificationDetails(categoryIdentifier: 'reminder'),
          ),
          androidScheduleMode: scheduleMode,
          payload: jsonEncode({'itemId': itemId}),
        );
      }
    }
  }

  Future<void> snooze({
    required String itemId,
    required String title,
    required DateTime until,
  }) async {
    await _plugin.zonedSchedule(
      id: _id('$itemId:snooze'),
      title: title,
      body: 'Snoozed reminder',
      scheduledDate: tz.TZDateTime.from(until, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'saved_find_reminders',
          'Saved find reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'reminder'),
      ),
      androidScheduleMode: await _scheduleMode(),
      payload: jsonEncode({'itemId': itemId}),
    );
  }

  Future<void> cancel(String itemId) async {
    await _plugin.cancel(id: _id(itemId));
    await _plugin.cancel(id: _id('$itemId:snooze'));
    for (var occurrence = 1; occurrence < 64; occurrence++) {
      await _plugin.cancel(id: _id('$itemId:custom:$occurrence'));
    }
  }

  void _handle(NotificationResponse response, {bool pending = false}) {
    try {
      final map = jsonDecode(response.payload ?? '') as Map<String, dynamic>;
      final itemId = map['itemId'] as String;
      final action = switch (response.actionId) {
        'snooze' => ReminderAction.snooze,
        'done' => ReminderAction.done,
        _ => ReminderAction.open,
      };
      final value = ReminderResponse(itemId, action);
      if (pending) {
        _pendingResponse = value;
      } else {
        _responses.add(value);
      }
    } catch (_) {
      // Ignore malformed notifications from a previous app version.
    }
  }

  int _id(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> dispose() => _responses.close();
}
