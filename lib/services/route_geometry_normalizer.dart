import 'dart:math';

import '../models/route_geometry_segment.dart';

class RouteGeometryNormalizer {
  final double connectionThresholdMeters;

  const RouteGeometryNormalizer({this.connectionThresholdMeters = 15});

  NormalizedRouteGeometry normalize(
    Iterable<RouteGeometrySegment> sourceSegments,
  ) {
    final source = sourceSegments
        .where((segment) => segment.points.length >= 2)
        .toList();
    if (source.isEmpty) {
      return NormalizedRouteGeometry(segments: const [], transfers: const []);
    }

    final normalized = <RouteGeometrySegment>[];
    final transfers = <RouteGeometryTransfer>[];
    var current = source.first;

    for (final next in source.skip(1)) {
      final currentEnd = current.points.last;
      final nextStart = next.points.first;
      final gapMeters = distanceMeters(currentEnd, nextStart);
      final isConnected = gapMeters <= connectionThresholdMeters;

      if (_sameTransport(current, next) && isConnected) {
        current = _copyWithPoints(
          current,
          _appendWithoutDuplicate(current.points, next.points),
        );
        continue;
      }

      if (isConnected && gapMeters > 0.5) {
        current = _copyWithPoints(current, [...current.points, nextStart]);
      } else if (!isConnected) {
        transfers.add(
          RouteGeometryTransfer(
            point: RouteGeometryPoint(
              latitude: (currentEnd.latitude + nextStart.latitude) / 2,
              longitude: (currentEnd.longitude + nextStart.longitude) / 2,
            ),
            gapMeters: gapMeters,
            label: _transferLabel(current, next),
          ),
        );
      }

      normalized.add(current);
      current = next;
    }

    normalized.add(current);
    return NormalizedRouteGeometry(segments: normalized, transfers: transfers);
  }

  double distanceMeters(RouteGeometryPoint first, RouteGeometryPoint second) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDifference = _radians(second.latitude - first.latitude);
    final longitudeDifference = _radians(second.longitude - first.longitude);
    final firstLatitude = _radians(first.latitude);
    final secondLatitude = _radians(second.latitude);
    final haversine =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(firstLatitude) *
            cos(secondLatitude) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);
    final normalizedHaversine = haversine.clamp(0.0, 1.0);
    return earthRadiusMeters *
        2 *
        atan2(sqrt(normalizedHaversine), sqrt(1 - normalizedHaversine));
  }

  bool _sameTransport(RouteGeometrySegment first, RouteGeometrySegment second) {
    return first.travelMode == second.travelMode &&
        first.vehicleType == second.vehicleType &&
        first.lineName == second.lineName &&
        first.lineColor == second.lineColor;
  }

  List<RouteGeometryPoint> _appendWithoutDuplicate(
    List<RouteGeometryPoint> first,
    List<RouteGeometryPoint> second,
  ) {
    final gapMeters = distanceMeters(first.last, second.first);
    return gapMeters <= 0.5
        ? [...first, ...second.skip(1)]
        : [...first, ...second];
  }

  RouteGeometrySegment _copyWithPoints(
    RouteGeometrySegment source,
    List<RouteGeometryPoint> points,
  ) {
    return RouteGeometrySegment(
      travelMode: source.travelMode,
      vehicleType: source.vehicleType,
      lineName: source.lineName,
      lineColor: source.lineColor,
      points: points,
    );
  }

  String _transferLabel(
    RouteGeometrySegment first,
    RouteGeometrySegment second,
  ) {
    final bothTransit =
        first.travelMode.toUpperCase() == 'TRANSIT' &&
        second.travelMode.toUpperCase() == 'TRANSIT';
    return bothTransit ? '站內轉乘' : '步行轉乘';
  }

  double _radians(double degrees) => degrees * pi / 180;
}
