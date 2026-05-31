import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

import 'database_helper.dart';
import 'models/watch.dart';

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

          if (response.statusCode != watch.expectedStatus) {
            hasError = true;
            errorMessage = 'Status code is ${response.statusCode}, expected ${watch.expectedStatus}.';
          } else if (watch.expectedString != null && watch.expectedString!.isNotEmpty) {
            if (!response.body.contains(watch.expectedString!)) {
              hasError = true;
              errorMessage = 'Expected string not found.';
            }
          }
        } catch (e) {
          hasError = true;
          errorMessage = 'Failed to connect: $e';
        }

        // Update database with last check time and status
        await dbHelper.update(watch.copyWith(
          lastCheckTime: now,
          lastStatus: currentStatus ?? 0,
        ));

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
