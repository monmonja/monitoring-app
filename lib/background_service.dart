import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

import 'database_helper.dart';

import 'models/watch_log.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log("Native called background task: $task");
    try {
      final dbHelper = DatabaseHelper.instance;
      final watches = await dbHelper.readAllWatches();

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      for (final watch in watches) {
        if (!watch.isActive) continue;

        // Check if interval has passed
        final now = DateTime.now();
        if (watch.lastCheckTime != null) {
          final difference = now.difference(watch.lastCheckTime!);
          if (difference.inMinutes < watch.intervalMinutes) {
            continue;
          }
        }

        bool hasError = false;
        String errorMessage = '';
        int? currentStatus;

        try {
          final response = await http.get(Uri.parse(watch.url));
          currentStatus = response.statusCode;

          if (response.statusCode < 200 || response.statusCode > 299) {
            hasError = true;
            errorMessage = 'Status code is ${response.statusCode}, expected 200-299.';
          } else if (watch.keyword != null && watch.keyword!.isNotEmpty) {
            if (!response.body.contains(watch.keyword!)) {
              hasError = true;
              errorMessage = 'Keyword "${watch.keyword!}" not found.';
            }
          }
        } catch (e) {
          hasError = true;
          errorMessage = 'Failed to connect: $e';
        }

        // Update database with last check time and status
        // If there was an error not related to status code (e.g. keyword or connection failed),
        // we can set lastStatus to something outside 200-299 so the UI knows it failed.
        // Or if status code was 200 but keyword failed, we mark lastStatus as -1 to flag it as DOWN.
        int statusToSave = currentStatus ?? 0;
        if (hasError && statusToSave >= 200 && statusToSave <= 299) {
          statusToSave = -1;
        }

        await dbHelper.update(watch.copyWith(
          lastCheckTime: now,
          lastStatus: statusToSave,
        ));

        // Create log entry
        if (watch.id != null) {
          await dbHelper.createWatchLog(WatchLog(
            watchId: watch.id!,
            timestamp: now,
            status: !hasError,
            statusCode: currentStatus, // Keep real status code in logs
            errorMessage: errorMessage.isNotEmpty ? errorMessage : null,
          ));
        }

        // Clean up old logs (older than 31 days)
        final thirtyOneDaysAgo = now.subtract(const Duration(days: 31));
        await dbHelper.deleteOldWatchLogs(thirtyOneDaysAgo);

        if (hasError) {
          // Show notification
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'watch_alert_channel',
            'Watch Alerts',
            channelDescription: 'Alerts when a watch fails its check',
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          await flutterLocalNotificationsPlugin.show(
            watch.id ?? 0,
            'Watch Alert: ${watch.name}',
            errorMessage,
            platformChannelSpecifics,
          );
        }
      }
    } catch (e) {
      developer.log("Error in background task: $e");
    }
    return Future.value(true);
  });
}
