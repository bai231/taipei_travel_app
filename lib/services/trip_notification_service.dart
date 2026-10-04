import 'package:flutter_local_notifications/flutter_local_notifications.dart';

String guardianDemoNotificationTitle(String title) {
  return title.replaceFirst(RegExp(r'^模擬[:：]\s*'), '').trim();
}

abstract interface class TripNotificationGateway {
  Future<void> initialize();

  Future<bool?> androidNotificationsEnabled();

  Future<void> showScheduleAdjusted({
    required int lateMinutes,
    required String nextStopName,
  });

  Future<void> showAlternativeAvailable({
    required int lateMinutes,
    required String nextStopName,
  });

  Future<void> showTransitRisk({
    required String reason,
    required String nextStopName,
  });

  Future<void> showWeatherAdvisory({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> showTestNotification({
    required String title,
    required String body,
  });
}

/// Shows the on-device notification used when the live itinerary falls behind.
class TripNotificationService implements TripNotificationGateway {
  static const _channelId = 'trip_schedule_alerts';
  static const _weatherChannelId = 'trip_weather_alerts';
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  static void Function(String? payload)? onNotificationTap;
  static int _testNotificationId = 7900;

  TripNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: const LinuxInitializationSettings(defaultActionName: '開啟'),
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      windows: WindowsInitializationSettings(
        appName: 'Taiwan Travel App',
        appUserModelId: 'com.sandy.taipei_travel_app',
        guid: '8ca31ca6-cdde-4f44-9d06-2a8c635a08b2',
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) =>
          onNotificationTap?.call(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  @override
  Future<bool?> androidNotificationsEnabled() async {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
  }

  @override
  Future<void> showScheduleAdjusted({
    required int lateMinutes,
    required String nextStopName,
  }) async {
    await initialize();
    await _plugin.show(
      7001,
      '今天的行程已重新安排',
      '目前約晚了 $lateMinutes 分鐘；已依您的位置調整後續景點，下一站是 $nextStopName。',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _weatherChannelId,
          '旅遊天氣提醒',
          channelDescription: '行程期間的降雨、紫外線與高溫提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        ),
        windows: WindowsNotificationDetails(),
      ),
      payload: 'guardian:alternative',
    );
  }

  @override
  Future<void> showAlternativeAvailable({
    required int lateMinutes,
    required String nextStopName,
  }) async {
    await initialize();
    await _plugin.show(
      7001,
      '行程可能延誤',
      '目前約晚了 $lateMinutes 分鐘；請開啟 App 檢查前往 $nextStopName 的備案，確認後才套用。',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '行程時間提醒',
          channelDescription: '旅程延誤與行程備案提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'guardian:alternative',
    );
  }

  @override
  Future<void> showTransitRisk({
    required String reason,
    required String nextStopName,
  }) async {
    await initialize();
    await _plugin.show(
      7002,
      '可能趕不上原班次',
      '$reason 請開啟 App 查詢前往 $nextStopName 的備案，確認後才套用。',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '行程時間提醒',
          channelDescription: '旅程延誤、轉乘風險與行程備案提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'guardian:transit',
    );
  }

  /// Delivers a standard on-device notification. It is deliberately limited to
  /// travel-weather advice and is not used for official disaster warnings.
  @override
  Future<void> showWeatherAdvisory({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _weatherChannelId,
          '旅遊天氣提醒',
          channelDescription: '行程期間的降雨、紫外線與高溫提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        ),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    _testNotificationId++;
    if (_testNotificationId > 7999) _testNotificationId = 7901;
    await _plugin.show(
      _testNotificationId,
      guardianDemoNotificationTitle(title),
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_guardian_promo_reason',
          '行程提醒',
          channelDescription: '行程、交通與天氣提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'guardian:test',
    );
  }
}
