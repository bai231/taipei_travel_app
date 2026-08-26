import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/route_planning/models/travel_leg.dart';
import '../models/tdx_route.dart';
import 'location_service.dart';

typedef NavigationUrlLauncher = Future<bool> Function(Uri uri);

class NavigationLaunchResult {
  final bool launched;
  final bool usedCurrentLocation;

  const NavigationLaunchResult({
    required this.launched,
    required this.usedCurrentLocation,
  });
}

class GoogleMapsNavigationService {
  final CurrentLocationGateway _locationGateway;
  final NavigationUrlLauncher _launcher;

  GoogleMapsNavigationService({
    CurrentLocationGateway? locationGateway,
    NavigationUrlLauncher? launcher,
  }) : _locationGateway = locationGateway ?? const LocationService(),
       _launcher = launcher ?? _launchMapsUrl;

  Future<NavigationLaunchResult> openTravelLeg(TravelLeg leg) async {
    final currentLocation = await _locationGateway.getCurrentLocation();
    final origin =
        currentLocation ??
        LocationPoint(
          latitude: leg.origin.latitude,
          longitude: leg.origin.longitude,
        );
    final uri = buildDirectionsUri(
      origin: origin,
      destination: LocationPoint(
        latitude: leg.destination.latitude,
        longitude: leg.destination.longitude,
      ),
      travelMode: travelModeForRoute(leg.route),
    );
    return NavigationLaunchResult(
      launched: await _launcher(uri),
      usedCurrentLocation: currentLocation != null,
    );
  }

  static Uri buildDirectionsUri({
    required LocationPoint origin,
    required LocationPoint destination,
    required String travelMode,
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': travelMode,
      'dir_action': 'navigate',
    });
  }

  static String travelModeForRoute(TdxRoute? route) {
    final modes =
        route?.sections.map((section) => section.mode.toLowerCase()).toSet() ??
        const <String>{};
    if (modes.any(_isTransitMode)) return 'transit';
    if (modes.any((mode) => mode == 'bike' || mode == 'cycle')) {
      return 'bicycling';
    }
    if (modes.any((mode) => mode == 'drive' || mode == 'car')) {
      return 'driving';
    }
    if (modes.isNotEmpty && modes.every(_isWalkingMode)) return 'walking';
    return 'transit';
  }

  static bool _isTransitMode(String mode) {
    return mode == 'transit' ||
        mode == 'bus' ||
        mode == 'metro' ||
        mode == 'subway' ||
        mode == 'train' ||
        mode == 'rail';
  }

  static bool _isWalkingMode(String mode) {
    return mode == 'pedestrian' || mode == 'walk' || mode == 'walking';
  }

  static Future<bool> _launchMapsUrl(Uri uri) {
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
  }
}
