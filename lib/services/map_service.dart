import 'package:flutter/material.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place.dart';
import '../models/route_geometry_segment.dart';

class MapService {
  static const LatLng taipeiCenter = LatLng(25.0330, 121.5654);

  const MapService();

  CameraPosition initialCameraPosition({LatLng? target}) =>
      CameraPosition(target: target ?? taipeiCenter, zoom: 12);

  Set<Marker> placeMarkers(Iterable<Place> places) {
    return places
        .map(
          (place) => Marker(
            markerId: MarkerId(place.id),
            position: LatLng(place.latitude, place.longitude),
            infoWindow: InfoWindow(title: place.name, snippet: place.address),
          ),
        )
        .toSet();
  }

  Marker currentLocationMarker({
    required double latitude,
    required double longitude,
  }) {
    return Marker(
      markerId: const MarkerId('current-location'),
      position: LatLng(latitude, longitude),
      infoWindow: const InfoWindow(title: '目前位置'),
    );
  }

  Polyline routePolyline(Iterable<Place> places) {
    return routePolylineForCoordinates(
      places.map((place) => LatLng(place.latitude, place.longitude)),
    );
  }

  Polyline routePolylineForCoordinates(Iterable<LatLng> coordinates) {
    return Polyline(
      polylineId: const PolylineId('trip-route'),
      points: coordinates.toList(),
      color: const Color(0xFF1976D2),
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
  }

  Set<Polyline> routePolylinesForSegments(
    Iterable<RouteGeometrySegment> segments,
  ) {
    return segments.indexed.map((entry) {
      final index = entry.$1;
      final segment = entry.$2;
      final isWalking = segment.travelMode.toUpperCase() == 'WALKING';
      return Polyline(
        polylineId: PolylineId('trip-route-$index'),
        points: segment.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(),
        color: _segmentColor(segment),
        width: isWalking ? 4 : 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        patterns: isWalking
            ? [PatternItem.dash(12), PatternItem.gap(8)]
            : const [],
      );
    }).toSet();
  }

  Color _segmentColor(RouteGeometrySegment segment) {
    final vehicleType = segment.vehicleType?.toUpperCase() ?? '';
    if (segment.travelMode.toUpperCase() == 'WALKING') {
      return const Color(0xFF616161);
    }
    if (segment.travelMode.toUpperCase() == 'DRIVING') {
      return const Color(0xFF2E7D32);
    }
    if (vehicleType.contains('SUBWAY') || vehicleType.contains('METRO')) {
      return const Color(0xFF1565C0);
    }
    if (vehicleType.contains('HIGH_SPEED')) {
      return const Color(0xFFC2185B);
    }
    if (vehicleType.contains('RAIL') || vehicleType.contains('TRAIN')) {
      return const Color(0xFF7B1FA2);
    }
    if (vehicleType.contains('BUS')) {
      return const Color(0xFFF57C00);
    }
    final googleColor = _parseHexColor(segment.lineColor);
    if (googleColor != null) return googleColor;
    return const Color(0xFF1976D2);
  }

  Color? _parseHexColor(String? value) {
    if (value == null) return null;
    final normalized = value.replaceFirst('#', '');
    if (normalized.length != 6) return null;
    final rgb = int.tryParse(normalized, radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  LatLngBounds boundsForPlaces(Iterable<Place> places) {
    return boundsForCoordinates(
      places.map((place) => LatLng(place.latitude, place.longitude)),
    );
  }

  LatLngBounds boundsForCoordinates(Iterable<LatLng> coordinates) {
    final coordinateList = coordinates.toList();
    if (coordinateList.isEmpty) {
      throw ArgumentError.value(coordinates, 'coordinates', '至少需要一個座標。');
    }

    var minimumLatitude = coordinateList.first.latitude;
    var maximumLatitude = coordinateList.first.latitude;
    var minimumLongitude = coordinateList.first.longitude;
    var maximumLongitude = coordinateList.first.longitude;

    for (final coordinate in coordinateList.skip(1)) {
      minimumLatitude = minimumLatitude < coordinate.latitude
          ? minimumLatitude
          : coordinate.latitude;
      maximumLatitude = maximumLatitude > coordinate.latitude
          ? maximumLatitude
          : coordinate.latitude;
      minimumLongitude = minimumLongitude < coordinate.longitude
          ? minimumLongitude
          : coordinate.longitude;
      maximumLongitude = maximumLongitude > coordinate.longitude
          ? maximumLongitude
          : coordinate.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minimumLatitude, minimumLongitude),
      northeast: LatLng(maximumLatitude, maximumLongitude),
    );
  }
}
