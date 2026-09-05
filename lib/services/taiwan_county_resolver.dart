import 'dart:convert';

import 'package:flutter/services.dart';

class TaiwanCountyResolver {
  static const assetPath = 'assets/geo/taiwan_counties.geojson';

  final List<_CountyGeometry> _counties;

  const TaiwanCountyResolver._(this._counties);

  static Future<TaiwanCountyResolver> load({AssetBundle? bundle}) async {
    final geoJson = await (bundle ?? rootBundle).loadString(assetPath);
    return TaiwanCountyResolver.fromGeoJson(geoJson);
  }

  factory TaiwanCountyResolver.fromGeoJson(String geoJson) {
    final root = jsonDecode(geoJson) as Map<String, dynamic>;
    final features = root['features'] as List<dynamic>? ?? const [];
    return TaiwanCountyResolver._(
      features
          .map(
            (feature) => _CountyGeometry.fromFeature(
              Map<String, dynamic>.from(feature as Map),
            ),
          )
          .where((county) => county.name.isNotEmpty)
          .toList(),
    );
  }

  String resolve({required double latitude, required double longitude}) {
    for (final county in _counties) {
      if (county.contains(latitude: latitude, longitude: longitude)) {
        return county.name;
      }
    }
    return '';
  }
}

class _CountyGeometry {
  final String name;
  final List<_Polygon> polygons;

  const _CountyGeometry({required this.name, required this.polygons});

  factory _CountyGeometry.fromFeature(Map<String, dynamic> feature) {
    final properties = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? const {},
    );
    final geometry = Map<String, dynamic>.from(
      feature['geometry'] as Map? ?? const {},
    );
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
    final polygons = <_Polygon>[];

    if (geometry['type'] == 'MultiPolygon') {
      for (final polygon in coordinates) {
        polygons.add(_Polygon.fromCoordinates(polygon as List<dynamic>));
      }
    } else if (geometry['type'] == 'Polygon') {
      polygons.add(_Polygon.fromCoordinates(coordinates));
    }

    return _CountyGeometry(
      name: _normalizeTaiwanText(properties['county']?.toString() ?? ''),
      polygons: polygons,
    );
  }

  bool contains({required double latitude, required double longitude}) {
    return polygons.any(
      (polygon) => polygon.contains(latitude: latitude, longitude: longitude),
    );
  }
}

class _Polygon {
  final List<List<_Coordinate>> rings;
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  const _Polygon({
    required this.rings,
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  factory _Polygon.fromCoordinates(List<dynamic> coordinates) {
    final rings = coordinates
        .map(
          (ring) => (ring as List<dynamic>)
              .map((point) => _Coordinate.fromGeoJson(point as List<dynamic>))
              .toList(),
        )
        .where((ring) => ring.length >= 3)
        .toList();
    final outerRing = rings.isEmpty ? const <_Coordinate>[] : rings.first;

    return _Polygon(
      rings: rings,
      minLatitude: outerRing.fold(
        double.infinity,
        (value, point) => point.latitude < value ? point.latitude : value,
      ),
      maxLatitude: outerRing.fold(
        double.negativeInfinity,
        (value, point) => point.latitude > value ? point.latitude : value,
      ),
      minLongitude: outerRing.fold(
        double.infinity,
        (value, point) => point.longitude < value ? point.longitude : value,
      ),
      maxLongitude: outerRing.fold(
        double.negativeInfinity,
        (value, point) => point.longitude > value ? point.longitude : value,
      ),
    );
  }

  bool contains({required double latitude, required double longitude}) {
    if (rings.isEmpty ||
        latitude < minLatitude ||
        latitude > maxLatitude ||
        longitude < minLongitude ||
        longitude > maxLongitude) {
      return false;
    }
    if (!_ringContains(rings.first, latitude, longitude)) return false;
    return !rings
        .skip(1)
        .any((hole) => _ringContains(hole, latitude, longitude));
  }

  static bool _ringContains(
    List<_Coordinate> ring,
    double latitude,
    double longitude,
  ) {
    var inside = false;
    for (
      var currentIndex = 0, previousIndex = ring.length - 1;
      currentIndex < ring.length;
      previousIndex = currentIndex++
    ) {
      final current = ring[currentIndex];
      final previous = ring[previousIndex];
      if (_isOnSegment(previous, current, latitude, longitude)) return true;

      final crossesLatitude =
          (current.latitude > latitude) != (previous.latitude > latitude);
      if (!crossesLatitude) continue;
      final intersectionLongitude =
          (previous.longitude - current.longitude) *
              (latitude - current.latitude) /
              (previous.latitude - current.latitude) +
          current.longitude;
      if (longitude < intersectionLongitude) inside = !inside;
    }
    return inside;
  }

  static bool _isOnSegment(
    _Coordinate start,
    _Coordinate end,
    double latitude,
    double longitude,
  ) {
    const tolerance = 1e-10;
    final cross =
        (longitude - start.longitude) * (end.latitude - start.latitude) -
        (latitude - start.latitude) * (end.longitude - start.longitude);
    if (cross.abs() > tolerance) return false;
    return latitude >=
            (start.latitude < end.latitude ? start.latitude : end.latitude) -
                tolerance &&
        latitude <=
            (start.latitude > end.latitude ? start.latitude : end.latitude) +
                tolerance &&
        longitude >=
            (start.longitude < end.longitude
                    ? start.longitude
                    : end.longitude) -
                tolerance &&
        longitude <=
            (start.longitude > end.longitude
                    ? start.longitude
                    : end.longitude) +
                tolerance;
  }
}

class _Coordinate {
  final double latitude;
  final double longitude;

  const _Coordinate({required this.latitude, required this.longitude});

  factory _Coordinate.fromGeoJson(List<dynamic> point) {
    return _Coordinate(
      longitude: (point[0] as num).toDouble(),
      latitude: (point[1] as num).toDouble(),
    );
  }
}

String _normalizeTaiwanText(String value) {
  return value.trim().replaceAll('臺', '台');
}
