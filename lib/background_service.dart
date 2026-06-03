import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'models/watch_log.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'watch_alert_channel', // id
    'Watch Alerts', // name
    description: 'Alerts when a watch fails its check', // description
    importance: Importance.max, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'watch_alert_channel',
      initialNotificationTitle: 'Watch App Service',
      initialNotificationContent: 'Monitoring watches...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  developer.log("Background service started");

  final dbHelper = DatabaseHelper.instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final battery = Battery();
  final connectivity = Connectivity();

  // Run the check loop periodically
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      final watches = await dbHelper.readAllWatches();

      // Get device states
      final prefs = await SharedPreferences.getInstance();
      final batteryMultiplier = prefs.getDouble('battery_multiplier') ?? 1.0;
      final batteryLevel = await battery.batteryLevel;
      final isBatterySaverOn = await battery.isInBatterySaveMode;

      final connectivityResult = await connectivity.checkConnectivity();
      final isWifi = connectivityResult.contains(ConnectivityResult.wifi);

      // Apply power policy: multiply interval if battery is low or in power save mode
      bool applyPowerPolicy = batteryLevel < 20 || isBatterySaverOn;
      int totalWatches = 0;
      int errorWatches = 0;

      for (final watch in watches) {
        if (!watch.isActive) continue;

        // Check if interval has passed
        final now = DateTime.now();
        if (watch.lastCheckTime != null) {
          final difference = now.difference(watch.lastCheckTime!);
          final effectiveInterval = applyPowerPolicy ? (watch.intervalMinutes * batteryMultiplier).ceil() : watch.intervalMinutes;

          if (difference.inMinutes < effectiveInterval) {
            continue;
          }
        }

        if (watch.wifiOnly && !isWifi) {
          // Log skipped check due to wifi policy
          if (watch.id != null) {
            await dbHelper.createWatchLog(WatchLog(
              watchId: watch.id!,
              timestamp: now,
              status: false,
              statusCode: 0,
              errorMessage: 'Skipped: Not on Wi-Fi',
              responseTimeMs: null,
            ));
          }
          // Update last check time without incrementing fails or alerting
          await dbHelper.update(watch.copyWith(lastCheckTime: now));
          continue;
        }

        bool hasError = false;
        String errorMessage = '';
        int? currentStatus;
        int? responseTimeMs;

        try {
          final stopwatch = Stopwatch()..start();

          Map<String, dynamic>? headersMap;
          if (watch.httpHeaders != null) {
            try {
              headersMap = jsonDecode(watch.httpHeaders!);
            } catch (e) {
              developer.log("Error decoding headers: $e");
            }
          }

          final options = Options(
            method: watch.httpMethod,
            headers: headersMap,
          );

          final response = await dio.request(
            watch.url,
            data: watch.httpBody,
            options: options,
          );

          stopwatch.stop();
          responseTimeMs = stopwatch.elapsedMilliseconds;
          currentStatus = response.statusCode;

          if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! > 299) {
            hasError = true;
            errorMessage = 'Status code is ${response.statusCode}, expected 200-299.';
          } else if (watch.keyword != null && watch.keyword!.isNotEmpty) {
            bool containsKeyword = response.data.toString().contains(watch.keyword!);
            if (watch.checkKeywordAbsence) {
              if (containsKeyword) {
                hasError = true;
                errorMessage = 'Keyword "${watch.keyword!}" was found (configured to alert on presence).';
              }
            } else {
              if (!containsKeyword) {
                hasError = true;
                errorMessage = 'Keyword "${watch.keyword!}" not found.';
              }
            }
          }

          if (!hasError && watch.latencyThreshold != null && responseTimeMs > watch.latencyThreshold!) {
            hasError = true;
            errorMessage = 'Response time ${responseTimeMs}ms exceeded threshold of ${watch.latencyThreshold}ms.';
          }

          if (!hasError && watch.alertOnSslExpiry && watch.url.startsWith('https')) {
            try {
              final uri = Uri.parse(watch.url);
              final socket = await SecureSocket.connect(uri.host, uri.port.toInt() == 0 ? 443 : uri.port,
                  timeout: const Duration(seconds: 5));
              final cert = socket.peerCertificate;
              if (cert != null) {
                final expiry = cert.endValidity;
                final daysUntilExpiry = expiry.difference(now).inDays;
                if (daysUntilExpiry <= 14) {
                  hasError = true;
                  errorMessage = 'SSL Certificate expires in $daysUntilExpiry days.';
                }
              }
              socket.destroy();
            } catch (e) {
              hasError = true;
              errorMessage = 'Failed to check SSL certificate: $e';
            }
          }
        } on DioException catch (e) {
          hasError = true;
          errorMessage = 'Network error: ${e.message}';
          currentStatus = e.response?.statusCode;
        } catch (e) {
          hasError = true;
          errorMessage = 'Failed to connect: $e';
        }

        // Retry logic: keep track of consecutive fails
        int updatedFails = hasError ? watch.consecutiveFails + 1 : 0;
        bool shouldAlert = hasError && updatedFails >= 3; // Retry Count logic

        totalWatches++;
        if (hasError) errorWatches++;

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
          consecutiveFails: updatedFails,
        ));

        // Create log entry
        if (watch.id != null) {
          await dbHelper.createWatchLog(WatchLog(
            watchId: watch.id!,
            timestamp: now,
            status: !hasError,
            statusCode: currentStatus, // Keep real status code in logs
            errorMessage: errorMessage.isNotEmpty ? errorMessage : null,
            responseTimeMs: responseTimeMs,
          ));
        }

        // Clean up old logs (older than 31 days)
        final thirtyOneDaysAgo = now.subtract(const Duration(days: 31));
        await dbHelper.deleteOldWatchLogs(thirtyOneDaysAgo);

        if (shouldAlert) {
          // Show notification
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'watch_alert_channel',
            'Watch Alerts',
            channelDescription: 'Alerts when a watch fails its check',
            importance: Importance.max,
            priority: Priority.high,
            groupKey: 'watch_alert_group',
          );
          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          await flutterLocalNotificationsPlugin.show(
            watch.id ?? 0,
            'Watch Alert: ${watch.name}',
            errorMessage,
            platformChannelSpecifics,
          );

          // Show Group Summary
          const AndroidNotificationDetails summaryAndroidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'watch_alert_channel',
            'Watch Alerts',
            channelDescription: 'Alerts when a watch fails its check',
            importance: Importance.max,
            priority: Priority.high,
            groupKey: 'watch_alert_group',
            setAsGroupSummary: true,
          );

          const NotificationDetails summaryPlatformChannelSpecifics =
              NotificationDetails(android: summaryAndroidPlatformChannelSpecifics);

          await flutterLocalNotificationsPlugin.show(
            0, // Group Summary ID
            'Watch Alerts Summary',
            'Multiple watches are experiencing issues.',
            summaryPlatformChannelSpecifics,
          );
        }
      }

      // Update widget
      String statusText = errorWatches > 0
          ? '$errorWatches / $totalWatches DOWN'
          : 'All $totalWatches systems UP';

      await HomeWidget.saveWidgetData<String>('widget_status', statusText);
      await HomeWidget.updateWidget(
        androidName: 'AppWidgetProvider',
      );

    } catch (e) {
      developer.log("Error in background timer: $e");
    }
  });
}
