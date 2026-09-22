import 'dart:convert';

import '../features/route_planning/models/route_travel_mode.dart';

class GoogleRouteRequestCache {
  static final shared = GoogleRouteRequestCache();

  final _values = <String, Object>{};
  final _pending = <String, Future<Object?>>{};

  static String request({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime departureTime,
    required RouteTravelMode travelMode,
  }) => jsonEncode({
    'origin': {'latitude': originLatitude, 'longitude': originLongitude},
    'destination': {
      'latitude': destinationLatitude,
      'longitude': destinationLongitude,
    },
    if (travelMode == RouteTravelMode.transit)
      'departureTime': departureTime.toUtc().toIso8601String(),
    'travelMode': travelMode.googleTravelMode,
  });

  Future<T> get<T>(
    String key,
    Future<T> Function() loader, {
    required bool Function(T) canCache,
  }) async {
    if (_values.containsKey(key)) return _values[key] as T;
    final existing = _pending[key];
    if (existing != null) return await existing as T;
    final pending = Future<T>.sync(loader);
    _pending[key] = pending;
    try {
      final value = await pending;
      if (value != null && canCache(value)) _values[key] = value;
      return value;
    } finally {
      _pending.remove(key);
    }
  }
}
