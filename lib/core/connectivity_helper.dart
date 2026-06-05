import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  ConnectivityHelper._();

  /// Returns true only if the device has an active Wi-Fi (or ethernet)
  /// network interface. Uses `NetworkInterface.list()` as the primary
  /// signal — this reads the actual kernel network interfaces and is
  /// more reliable than `connectivity_plus` in background mode, where
  /// the latter can return cached results or report Wi-Fi when the OS
  /// has silently fallen back to mobile data.
  static Future<bool> isOnWifi() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final hasWifiInterface = interfaces.any((i) {
        final name = i.name.toLowerCase();
        return name.startsWith('wlan') ||
            name.startsWith('wi') ||
            name.startsWith('eth');
      });
      if (hasWifiInterface) return true;

      // Fallback: ask connectivity_plus, but only treat it as Wi-Fi if
      // mobile is NOT also reported (Android can report both during
      // network transitions).
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.wifi) &&
          !result.contains(ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }
}
