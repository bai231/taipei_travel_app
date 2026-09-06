import 'dart:convert';
import 'dart:js_interop';

import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';
import 'google_route_planning_gateway.dart';
import 'google_route_planning_response.dart';

@JS('computeGoogleRouteInformation')
external JSPromise<JSString> _computeGoogleRouteInformation(
  JSString requestJson,
);

class GoogleRoutePlanningService implements GoogleRoutePlanningGateway {
  static final Map<String, Map<String, dynamic>?> _cache = {};

  const GoogleRoutePlanningService();

  @override
  Future<TdxRoute?> getRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required DateTime requestedDeparture,
    required RouteTravelMode travelMode,
  }) async {
    if (travelMode == RouteTravelMode.transit) {
      throw ArgumentError.value(travelMode, 'travelMode', '大眾運輸必須使用 TDX 查詢。');
    }

    final request = jsonEncode({
      'origin': {'latitude': originLatitude, 'longitude': originLongitude},
      'destination': {
        'latitude': destinationLatitude,
        'longitude': destinationLongitude,
      },
      'travelMode': travelMode.googleTravelMode,
    });
    final response = _cache.containsKey(request)
        ? _cache[request]
        : await _load(request);
    return parseGoogleRouteInformation(
      response: response,
      requestedDeparture: requestedDeparture,
      travelMode: travelMode,
    );
  }

  Future<Map<String, dynamic>?> _load(String request) async {
    final raw = (await _computeGoogleRouteInformation(
      request.toJS,
    ).toDart).toDart;
    final decoded = jsonDecode(raw);
    final response = decoded is Map<String, dynamic> ? decoded : null;
    _cache[request] = response;
    return response;
  }
}
