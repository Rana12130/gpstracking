// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_state.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(initializationSettings);
  }

  Future<void> showNotification(String title, String body) async {
    try {
      const NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          'location_assistant',
          'Location Assistant',
          channelDescription: 'Notifications for location arrivals',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentBadge: true,
          presentAlert: true,
        ),
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      if (kDebugMode) print("Notification error: $e");
    }
  }
}