import '../features/route_planning/models/route_travel_mode.dart';
import '../models/tdx_route.dart';

TdxRoute? parseGoogleRouteInformation({
  required Map<String, dynamic>? response,
  required DateTime requestedDeparture,
  required RouteTravelMode travelMode,
}) {
  if (response == null) return null;
  final durationMillis = (response['durationMillis'] as num?)?.toInt() ?? 0;
  if (durationMillis <= 0) return null;
  final travelSeconds = (durationMillis / 1000).ceil();
  final distanceMeters = (response['distanceMeters'] as num?)?.toInt();
  final sections = travelMode == RouteTravelMode.transit
      ? _transitSections(response['steps'])
      : [
          RouteSection(
            mode: travelMode.sectionMode,
            travelTime: travelSeconds,
            stopCount: 0,
            intermediateStops: const [],
          ),
        ];
  // A walking-only or details-free result must not masquerade as a verified
  // public-transport alternative to TDX.
  if (travelMode == RouteTravelMode.transit &&
      !sections.any((section) => section.mode != 'pedestrian')) {
    return null;
  }
  var arrival = requestedDeparture.add(Duration(seconds: travelSeconds));
  if (travelMode == RouteTravelMode.transit) {
    // Route.duration may omit waiting before the first departure. Never show
    // an arrival earlier than a returned vehicle's scheduled arrival.
    for (var index = 0; index < sections.length; index++) {
      final scheduledArrival = sections[index].scheduledArrival;
      if (scheduledArrival == null) continue;
      final trailingWalkSeconds = sections
          .skip(index + 1)
          .where((section) => section.mode == 'pedestrian')
          .fold<int>(0, (sum, section) => sum + section.travelTime);
      final endpoint = scheduledArrival.add(
        Duration(seconds: trailingWalkSeconds),
      );
      if (endpoint.isAfter(arrival)) arrival = endpoint;
    }
  }
  final effectiveSeconds = arrival.difference(requestedDeparture).inSeconds;
  return TdxRoute(
    transfers: travelMode == RouteTravelMode.transit
        ? (sections.where((section) => section.mode != 'pedestrian').length - 1)
              .clamp(0, 1 << 30)
        : 0,
    travelTime: effectiveSeconds,
    startTime: requestedDeparture,
    endTime: arrival,
    distanceMeters: distanceMeters,
    sections: sections,
    provider: RouteProvider.google,
  );
}

List<RouteSection> _transitSections(Object? rawSteps) {
  final sections = <RouteSection>[];
  for (final raw in rawSteps is List ? rawSteps : const []) {
    if (raw is! Map) continue;
    final step = Map<String, dynamic>.from(raw);
    final details = _map(step['transitDetails']);
    final line = _map(details?['transitLine']);
    final vehicle = _map(line?['vehicle']);
    final stopDetails = _map(details?['stopDetails']);
    final departureStop = _map(
      details?['departureStop'] ?? stopDetails?['departureStop'],
    );
    final arrivalStop = _map(
      details?['arrivalStop'] ?? stopDetails?['arrivalStop'],
    );
    final departure = _date(
      details?['departureTime'] ?? stopDetails?['departureTime'],
    );
    final arrival = _date(
      details?['arrivalTime'] ?? stopDetails?['arrivalTime'],
    );
    final mode = step['travelMode']?.toString().toUpperCase();
    final isTransit = mode == 'TRANSIT' && details != null;
    if (!isTransit && mode != 'WALKING' && mode != 'WALK') continue;
    final seconds = isTransit && departure != null && arrival != null
        ? arrival.difference(departure).inSeconds
        : _durationSeconds(step);
    sections.add(
      RouteSection(
        mode: isTransit ? _transitMode(vehicle?['type']) : 'pedestrian',
        lineName: isTransit
            ? (line?['nameShort'] ?? line?['shortName'] ?? line?['name'])
                  ?.toString()
            : null,
        destination: details?['headsign']?.toString(),
        departureTitle: departureStop?['name']?.toString(),
        arrivalTitle: arrivalStop?['name']?.toString(),
        departureTime: _clock(departure),
        arrivalTime: _clock(arrival),
        travelTime: seconds < 0 ? 0 : seconds,
        stopCount: (details?['stopCount'] as num?)?.toInt() ?? 0,
        intermediateStops: const [],
        scheduledDeparture: departure,
        scheduledArrival: arrival,
      ),
    );
  }
  return sections;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _durationSeconds(Map<String, dynamic> step) {
  final millis = step['staticDurationMillis'];
  if (millis is num) return (millis / 1000).ceil();
  final raw = step['staticDuration']?.toString();
  return int.tryParse(raw?.replaceFirst(RegExp(r's$'), '') ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String? _clock(DateTime? value) => value == null
    ? null
    : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _transitMode(Object? vehicleType) {
  final type = vehicleType?.toString().toUpperCase() ?? '';
  if (type.contains('BUS')) return 'bus';
  if (type.contains('SUBWAY') || type.contains('METRO') || type == 'TRAM') {
    return 'metro';
  }
  if (type.contains('TRAIN') || type.contains('RAIL')) return 'train';
  return 'transit';
}
