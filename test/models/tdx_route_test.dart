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

  test('保留 MaaS 班次、營運者、站點座標及完整時間供即時監測', () {
    final section = RouteSection.fromJson({
      'type': 'transit',
      'transport': {
        'mode': 'TRA',
        'category': 'TRA',
        'uuid': 'trip-uuid',
        'number': '123',
        'city': 'Taipei',
      },
      'agency': {'agency_id': 'TRA'},
      'departure': {
        'time': '2026-09-22T10:05:00+08:00',
        'place': {
          'name': '臺北',
          'stationID': '1000',
          'location': {'lat': 25.04775, 'lng': 121.51711},
        },
      },
      'arrival': {
        'time': '2026-09-22T11:10:00+08:00',
        'place': {
          'name': '新竹',
          'stationID': '1210',
          'location': {'lat': 24.8016, 'lng': 120.97159},
        },
      },
      'travelSummary': {'duration': 3900},
    });

    expect(section.operatorCode, 'TRA');
    expect(section.agencyId, 'TRA');
    expect(section.serviceId, 'trip-uuid');
    expect(section.routeId, '123');
    expect(section.departureStopId, '1000');
    expect(section.arrivalStopId, '1210');
    expect(section.departureLatitude, closeTo(25.04775, .00001));
    expect(section.arrivalLongitude, closeTo(120.97159, .00001));
    expect(section.scheduledDeparture?.hour, 10);
    expect(section.scheduledArrival?.minute, 10);
  });
}
