import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'flowly_events',
    'Flowly events',
    description: 'Budget, goals, review and recurring events',
    importance: Importance.defaultImportance,
  );
  Future<void> initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();
  }

  Future<bool> enabled(String event) async =>
      (await SharedPreferences.getInstance()).getBool('notifications.$event') ??
      true;
  Future<void> setEnabled(String event, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        'notifications.$event',
        value,
      );
  Future<void> show({
    required String event,
    required int id,
    required String title,
    required String body,
  }) async {
    if (await enabled(event)) {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
          ),
        ),
      );
    }
  }
}
