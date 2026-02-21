import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _taskChannelId = 'mclaw_task_channel';
  static const String _taskChannelName = 'MClaw Tasks';
  static const String _taskChannelDescription = 'Task completion notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _isAppForeground = true;

  bool get isAppForeground => _isAppForeground;

  void setAppForeground(bool isForeground) {
    _isAppForeground = isForeground;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      _taskChannelId,
      _taskChannelName,
      description: _taskChannelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) {
      return true;
    }

    final enabled = await androidImpl.areNotificationsEnabled();
    if (enabled == true) {
      return true;
    }
    return await androidImpl.requestNotificationsPermission() ?? false;
  }

  Future<void> showTaskCompletedNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        channelDescription: _taskChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
