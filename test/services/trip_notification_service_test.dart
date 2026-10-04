import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/services/trip_notification_service.dart';

void main() {
  test('保母示範通知直接顯示觸發原因', () {
    expect(
      guardianDemoNotificationTitle('行程可能延誤'),
      '行程可能延誤',
    );
    expect(
      guardianDemoNotificationTitle('模擬：稍後可能下雨'),
      '稍後可能下雨',
    );
  });
}
