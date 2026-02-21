import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundRuntimeService {
  BackgroundRuntimeService._();

  static final BackgroundRuntimeService instance = BackgroundRuntimeService._();

  static const String _channelId = 'mclaw_background_channel';
  static const int _foregroundNotificationId = 9037;

  bool _configured = false;

  Future<void> configure() async {
    if (_configured) {
      return;
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      'MClaw Background',
      description: 'Keeps MClaw running in background',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: mclawBackgroundServiceOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'MClaw',
        initialNotificationContent: '后台运行已开启',
        foregroundServiceNotificationId: _foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );

    _configured = true;
  }

  Future<void> enable() async {
    await configure();
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('setForeground');
      return;
    }
    await service.startService();
  }

  Future<void> disable() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
void mclawBackgroundServiceOnStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  service.on('setForeground').listen((_) {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
  });

  service.on('setBackground').listen((_) {
    if (service is AndroidServiceInstance) {
      service.setAsBackgroundService();
    }
  });

  Timer.periodic(const Duration(minutes: 1), (timer) {
    if (service is! AndroidServiceInstance) {
      return;
    }

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    service.setForegroundNotificationInfo(
      title: 'MClaw',
      content: '后台运行中 $hh:$mm',
    );
  });
}
