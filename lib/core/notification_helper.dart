import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/watch.dart';

class NotificationHelper {
  NotificationHelper._();

  static const String _channelId = 'watch_alert_channel';
  static const String _channelName = 'Watch Alerts';
  static const String _channelDescription = 'Alerts when a watch fails its check';
  static const String _groupKey = 'watch_alert_group';
  static const int _groupSummaryId = 0;
  static const int _foregroundServiceId = 888;

  static FlutterLocalNotificationsPlugin? _plugin;

  static FlutterLocalNotificationsPlugin get _notifications {
    _plugin ??= FlutterLocalNotificationsPlugin();
    return _plugin!;
  }

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notifications.initialize(initializationSettings);

    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      );
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  static int get foregroundServiceId => _foregroundServiceId;

  static Future<void> showWatchAlert({
    required Watch watch,
    required String errorMessage,
    int? statusCode,
  }) async {
    final body = statusCode != null
        ? '[$statusCode] $errorMessage'
        : errorMessage;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      groupKey: _groupKey,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      watch.id ?? 0,
      'Watch Alert: ${watch.name}',
      body,
      platformChannelSpecifics,
    );

    const AndroidNotificationDetails summaryAndroidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      groupKey: _groupKey,
      setAsGroupSummary: true,
    );
    const NotificationDetails summaryPlatformChannelSpecifics =
        NotificationDetails(android: summaryAndroidPlatformChannelSpecifics);

    await _notifications.show(
      _groupSummaryId,
      'Watch Alerts Summary',
      'Multiple watches are experiencing issues.',
      summaryPlatformChannelSpecifics,
    );
  }
}
