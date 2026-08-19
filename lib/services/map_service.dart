import 'package:flutter/material.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place.dart';

class MapService {
  static const LatLng taipeiCenter = LatLng(25.0330, 121.5654);

  const MapService();

  CameraPosition initialCameraPosition({LatLng? target}) => CameraPosition(target: target ?? taipeiCenter, zoom: 12);

  Set<Marker> placeMarkers(Iterable<Place> places) {
    return places.map((place) => Marker(
      markerId: MarkerId(place.id),
      position: LatLng(place.latitude, place.longitude),
      infoWindow: InfoWindow(title: place.name, snippet: place.address),
    )).toSet();
  }

  Marker currentLocationMarker({required double latitude, required double longitude}) {
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
    );
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
      minimumLatitude = minimumLatitude < coordinate.latitude ? minimumLatitude : coordinate.latitude;
      maximumLatitude = maximumLatitude > coordinate.latitude ? maximumLatitude : coordinate.latitude;
      minimumLongitude = minimumLongitude < coordinate.longitude ? minimumLongitude : coordinate.longitude;
      maximumLongitude = maximumLongitude > coordinate.longitude ? maximumLongitude : coordinate.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minimumLatitude, minimumLongitude),
      northeast: LatLng(maximumLatitude, maximumLongitude),
    );
  }
}
