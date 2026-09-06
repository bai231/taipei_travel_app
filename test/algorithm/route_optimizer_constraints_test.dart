import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';

void main() {
  test('排序成本包含最後一站到住宿終點的交通', () {
    final result = RouteOptimizer().optimizeRoute(
      stopsToVisit: const [
        RouteStop(
          id: 'a',
          name: 'a',
          latitude: 25,
          longitude: 121,
          stayDurationMinutes: 0,
        ),
        RouteStop(
          id: 'b',
          name: 'b',
          latitude: 25,
          longitude: 121,
          stayDurationMinutes: 0,
        ),
      ],
      durationMatrix: [
        [0, 10],
        [10, 0],
      ],
      travelTimesToEnd: [100, 1],
      startTimeMinutes: 0,
    );
    expect(result.sortedStops.map((stop) => stop.id), ['a', 'b']);
    expect(result.totalTimeMinutes, 11);
  });

  test('可行排序優先於違反固定時間但數字成本較低的排序', () {
    final result = RouteOptimizer().optimizeRoute(
      stopsToVisit: const [
        RouteStop(
          id: 'fixed',
          name: 'fixed',
          latitude: 25,
          longitude: 121,
          stayDurationMinutes: 0,
          latestTimeMinutes: 0,
        ),
        RouteStop(
          id: 'flexible',
          name: 'flexible',
          latitude: 25,
          longitude: 121,
          stayDurationMinutes: 10,
        ),
      ],
      durationMatrix: [
        [0, 20000],
        [0, 0],
      ],
      startTimeMinutes: 0,
    );
    expect(result.isValid, isTrue);
    expect(result.sortedStops.first.id, 'fixed');
  });
}
