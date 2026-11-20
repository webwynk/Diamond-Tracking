import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The low-battery notification, shown by the tracker service so it appears
/// even when the app is closed.
class BatteryAlerts {
  BatteryAlerts([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _id = 4102;

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<void> show(int level) async {
    await init();
    await _plugin.show(
      id: _id,
      title: 'Battery $level%',
      body: batteryMessage(level),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'battery_warnings',
          'Battery warnings',
          channelDescription: 'Low battery while you are on duty',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
    );
  }
}

/// The text of the battery warning, shared by the notification and the
/// in-app popup.
String batteryMessage(int level) => level <= 10
    ? 'Charge your phone now. If it switches off, your route stops being '
          'recorded.'
    : 'Charge your phone soon so your route keeps being recorded.';
