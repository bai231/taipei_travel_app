import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows the on-device notification used when the live itinerary falls behind.
class TripNotificationService {
  static const _channelId = 'trip_schedule_alerts';
  static const _weatherChannelId = 'trip_weather_alerts';
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  TripNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
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
          _channelId,
          '行程時間提醒',
          channelDescription: '旅程延誤與當日行程更新提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Delivers a standard on-device notification. It is deliberately limited to
  /// travel-weather advice and is not used for official disaster warnings.
  Future<void> showWeatherAdvisory({
    required int id,
    required String title,
    required String body,
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
      ),
    );
  }
}
