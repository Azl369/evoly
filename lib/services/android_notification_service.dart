import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:evoly/services/notification_service.dart';

/// Android 本地通知实现，基于 flutter_local_notifications。
class AndroidNotificationService implements NotificationService {
  AndroidNotificationService();

  static const String _channelId = 'evoly_reminders';
  static const String _channelName = 'Evoly 提醒';
  static const String _channelDescription = 'Evoly 目标与任务提醒通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          handleAndroidBackgroundNotificationResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  @override
  Future<void> showNow({
    required String id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: stableAndroidNotificationId(id),
      title: title,
      body: body,
      notificationDetails: _details(),
      payload: id,
    );
  }

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (!scheduledAt.isAfter(DateTime.now())) {
      await showNow(id: id, title: title, body: body);
      return;
    }

    try {
      await _zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Evoly notification exact schedule failed, fallback to inexact: '
        '${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancel(String id) async {
    await _plugin.cancel(id: stableAndroidNotificationId(id));
  }

  Future<void> _zonedSchedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required AndroidScheduleMode scheduleMode,
  }) {
    return _plugin.zonedSchedule(
      id: stableAndroidNotificationId(id),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: scheduleMode,
      payload: id,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint(
      'Evoly notification tapped: id=${response.id}, '
      'payload=${response.payload}, action=${response.actionId}',
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}

@pragma('vm:entry-point')
void handleAndroidBackgroundNotificationResponse(
    NotificationResponse response) {
  debugPrint(
    'Evoly notification background response: id=${response.id}, '
    'payload=${response.payload}, action=${response.actionId}',
  );
}

@visibleForTesting
int stableAndroidNotificationId(String value) {
  const int fnvPrime = 16777619;
  const int fnvOffsetBasis = 2166136261;

  var hash = fnvOffsetBasis;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0x7fffffff;
  }

  return hash == 0 ? 1 : hash;
}
