import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // 1. Method untuk inisialisasi permission
  static Future<void> initialize() async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  // 2. Method untuk menjadwalkan alarm
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: scheduledTime,
      assetAudioPath: 'assets/sounds/alarm.mp3', 
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      fadeDuration: 3.0, 
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Matikan Alarm', 
      ),
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  // 3. Method untuk membatalkan alarm (Ini yang menyebabkan error tadi)
  static Future<void> cancelNotification(int id) async {
    await Alarm.stop(id);
  }
}