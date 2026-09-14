import 'dart:convert';
import 'dart:js_interop';

import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';
import 'google_route_planning_gateway.dart';
import 'google_route_planning_response.dart';
import 'google_route_request_cache.dart';

@JS('computeGoogleRouteInformation')
external JSPromise<JSString> _computeGoogleRouteInformation(
  JSString requestJson,
);

class GoogleRoutePlanningService implements GoogleRoutePlanningGateway {
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

    final request = GoogleRouteRequestCache.request(
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      departureTime: requestedDeparture,
      travelMode: travelMode,
    );
    final response = await GoogleRouteRequestCache.shared.get(
      'information:$request',
      () => _load(request),
      canCache: (value) =>
          value != null && ((value['durationMillis'] as num?) ?? 0) > 0,
    );
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
    return response;
  }
}
