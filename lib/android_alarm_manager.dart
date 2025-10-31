import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AndroidAlarmManager {
  static const MethodChannel _channel = MethodChannel('android_alarm_manager_plus');

  static Future<void> initialize() async {
    // Optional init logic
  }

  static Future<void> cancel(int id) async {
    try {
      await _channel.invokeMethod('cancel', {'id': id});
    } catch (e) {
      debugPrint('Error cancelling alarm: $e');
    }
  }

  static Future<void> oneShotAt(
      DateTime time,
      int id,
      Function callback, {
        bool exact = true,
        bool wakeup = true,
      }) async {
    final callbackHandle = PluginUtilities.getCallbackHandle(callback);
    if (callbackHandle == null) {
      throw ArgumentError('Callback must be a top-level or static function');
    }

    try {
      await _channel.invokeMethod('oneShotAt', {
        'time': time.millisecondsSinceEpoch,
        'id': id,
        'exact': exact,
        'wakeup': wakeup,
        'handle': callbackHandle.toRawHandle(),
      });
    } catch (e) {
      debugPrint('Error scheduling alarm: $e');
    }
  }
}
