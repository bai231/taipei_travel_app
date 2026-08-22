import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';

void main() {
  test('從 TDX transport.mode 辨識高鐵', () {
    final section = RouteSection.fromJson({
      'type': 'transit',
      'transport': {'mode': 'HighSpeedRail', 'name': '高鐵 123'},
      'travelSummary': {'duration': 5400},
    });

    expect(section.mode, 'high_speed_rail');
    expect(section.lineName, '高鐵 123');
  });

  test('從 TDX transport.mode 辨識台鐵', () {
    final section = RouteSection.fromJson({
      'type': 'transit',
      'transport': {'mode': 'Rail', 'name': '臺鐵自強號'},
      'travelSummary': {'duration': 7200},
    });

    expect(section.mode, 'train');
  });
}
