class RouteGeometryPoint {
  final double latitude;
  final double longitude;

  const RouteGeometryPoint({required this.latitude, required this.longitude});

  factory RouteGeometryPoint.fromJson(Map<String, dynamic> json) {
    return RouteGeometryPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class RouteGeometrySegment {
  final String travelMode;
  final String? vehicleType;
  final String? lineName;
  final String? lineColor;
  final List<RouteGeometryPoint> points;

  RouteGeometrySegment({
    required this.travelMode,
    this.vehicleType,
    this.lineName,
    this.lineColor,
    required List<RouteGeometryPoint> points,
  }) : points = List.unmodifiable(points);

  factory RouteGeometrySegment.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['points'] as List<dynamic>? ?? const [];
    return RouteGeometrySegment(
      travelMode: json['travelMode']?.toString() ?? 'TRANSIT',
      vehicleType: json['vehicleType']?.toString(),
      lineName: json['lineName']?.toString(),
      lineColor: json['lineColor']?.toString(),
      points: pointsJson
          .whereType<Map<String, dynamic>>()
          .map(RouteGeometryPoint.fromJson)
          .toList(),
    );
  }
}

class RouteGeometryTransfer {
  final RouteGeometryPoint point;
  final double gapMeters;
  final String label;

  const RouteGeometryTransfer({
    required this.point,
    required this.gapMeters,
    required this.label,
  });
}

class NormalizedRouteGeometry {
  final List<RouteGeometrySegment> segments;
  final List<RouteGeometryTransfer> transfers;

  NormalizedRouteGeometry({
    required List<RouteGeometrySegment> segments,
    required List<RouteGeometryTransfer> transfers,
  }) : segments = List.unmodifiable(segments),
       transfers = List.unmodifiable(transfers);
}
