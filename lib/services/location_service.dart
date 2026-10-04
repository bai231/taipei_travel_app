import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationPoint {
  final double latitude;
  final double longitude;

  const LocationPoint({required this.latitude, required this.longitude});
}

abstract interface class CurrentLocationGateway {
  Future<LocationPoint?> getCurrentLocation();
}

/// A location gateway that can keep reporting positions while a trip is active.
abstract interface class LocationTrackingGateway
    implements CurrentLocationGateway {
  Stream<LocationPoint> watchLocation();
}

class LocationService implements LocationTrackingGateway {
  final Duration timeout;

  const LocationService({this.timeout = const Duration(seconds: 8)});

  @override
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to obtain the current location: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Stream<LocationPoint> watchLocation() async* {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('Location services are disabled.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      yield* Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).map(
        (position) => LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Location tracking ended: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
  static double getDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
