import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/route_geometry_segment.dart';
import 'package:taipei_travel_app/services/route_geometry_normalizer.dart';

void main() {
  const normalizer = RouteGeometryNormalizer();

  test('相鄰且相同交通方式的 step 會合併', () {
    final result = normalizer.normalize([
      _segment(mode: 'WALKING', points: const [_pointA, _pointB]),
      _segment(mode: 'WALKING', points: const [_pointB, _pointC]),
    ]);

    expect(result.segments, hasLength(1));
    expect(result.segments.single.points, hasLength(3));
    expect(result.transfers, isEmpty);
  });

  test('不同交通方式端點小於十五公尺時會自動銜接', () {
    const nearbyPoint = RouteGeometryPoint(
      latitude: 25.00005,
      longitude: 121.001,
    );
    final result = normalizer.normalize([
      _segment(mode: 'WALKING', points: const [_pointA, _pointB]),
      _segment(
        mode: 'TRANSIT',
        vehicleType: 'BUS',
        points: const [nearbyPoint, _pointC],
      ),
    ]);

    expect(result.segments, hasLength(2));
    expect(result.segments.first.points.last, same(nearbyPoint));
    expect(result.transfers, isEmpty);
  });

  test('端點超過十五公尺時保留間距並建立轉乘標記', () {
    const distantPoint = RouteGeometryPoint(
      latitude: 25.0003,
      longitude: 121.001,
    );
    final result = normalizer.normalize([
      _segment(
        mode: 'TRANSIT',
        lineName: '紅線',
        points: const [_pointA, _pointB],
      ),
      _segment(
        mode: 'TRANSIT',
        lineName: '藍線',
        points: const [distantPoint, _pointC],
      ),
    ]);

    expect(result.segments, hasLength(2));
    expect(result.transfers, hasLength(1));
    expect(result.transfers.single.label, '站內轉乘');
    expect(result.transfers.single.gapMeters, greaterThan(15));
  });
}

const _pointA = RouteGeometryPoint(latitude: 25.0, longitude: 121.0);
const _pointB = RouteGeometryPoint(latitude: 25.0, longitude: 121.001);
const _pointC = RouteGeometryPoint(latitude: 25.001, longitude: 121.002);

RouteGeometrySegment _segment({
  required String mode,
  String? vehicleType,
  String? lineName,
  required List<RouteGeometryPoint> points,
}) {
  return RouteGeometrySegment(
    travelMode: mode,
    vehicleType: vehicleType,
    lineName: lineName,
    points: points,
  );
}
