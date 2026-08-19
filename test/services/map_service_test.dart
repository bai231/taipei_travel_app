import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/route_geometry_segment.dart';
import 'package:taipei_travel_app/services/map_service.dart';

void main() {
  test('依照交通方式建立多段實際路徑', () {
    const service = MapService();
    final polylines = service.routePolylinesForSegments([
      RouteGeometrySegment(
        travelMode: 'WALKING',
        points: const [
          RouteGeometryPoint(latitude: 25.0478, longitude: 121.5170),
          RouteGeometryPoint(latitude: 25.0480, longitude: 121.5180),
        ],
      ),
      RouteGeometrySegment(
        travelMode: 'TRANSIT',
        vehicleType: 'BUS',
        points: const [
          RouteGeometryPoint(latitude: 25.0480, longitude: 121.5180),
          RouteGeometryPoint(latitude: 25.0520, longitude: 121.5250),
          RouteGeometryPoint(latitude: 25.0570, longitude: 121.5300),
        ],
      ),
    ]);

    expect(polylines, hasLength(2));
    final walking = polylines.firstWhere(
      (polyline) => polyline.polylineId.value == 'trip-route-0',
    );
    final bus = polylines.firstWhere(
      (polyline) => polyline.polylineId.value == 'trip-route-1',
    );
    expect(walking.points, hasLength(2));
    expect(walking.patterns, isNotEmpty);
    expect(bus.points, hasLength(3));
    expect(bus.patterns, isEmpty);
    expect(bus.color.toARGB32(), 0xFFF57C00);
  });
}
