import '../algorithm/route_optimizer.dart';
import '../features/route_planning/models/route_day.dart';
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/models/route_place_input.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import '../features/route_planning/models/route_visit.dart';
import '../features/route_planning/models/travel_leg.dart';
import '../models/place.dart';
import '../models/scheduled_visit.dart';
import '../models/tdx_route.dart';
import '../models/travel_preference.dart';
import '../models/trip_request.dart';
import '../models/visit_preferences.dart';
import 'itinerary_snapshot.dart';

/// Restores the display result and the original planner inputs from a v2
/// snapshot. Opening a saved trip must not call the route APIs or reschedule it.
RouteItinerary itineraryFromSnapshot(Map<String, dynamic> raw) {
  final snapshot = decodeItinerarySnapshot(raw);
  final requestData = _map(snapshot['request'], 'request');
  final request = TripRequest(
    title: _string(requestData['title']),
    startDate: _date(requestData['startDate'], 'request.startDate'),
    endDate: _date(requestData['endDate'], 'request.endDate'),
    location: _string(requestData['location']),
    people: _int(requestData['people'], 1),
    budget_level: _int(requestData['budgetLevel'], 0),
    preferences: _strings(requestData['preferences']),
    aiPrompt: _string(requestData['aiPrompt']),
    parsedPreference: requestData['parsedPreference'] is Map
        ? TravelPreference.fromJson(
            _map(requestData['parsedPreference'], 'parsedPreference'),
          )
        : null,
  );
  final origin = _stop(_map(snapshot['origin'], 'origin'));
  final days = <RouteDay>[
    for (final (index, value) in _rows(snapshot['days'], 'days').indexed)
      _day(_map(value, 'days[$index]')),
  ];
  if (days.isEmpty) throw const FormatException('行程快照沒有每日資料');

  final savedInputs = <RoutePlaceInput>[
    for (final (index, value) in _rows(snapshot['inputs'], 'inputs').indexed)
      _input(_map(value, 'inputs[$index]')),
  ];
  // Early v2 data may lack `inputs`. Keep the displayed visits, but derive
  // editable choices without treating generated hotel check-ins as selections.
  final inputs = savedInputs.isNotEmpty
      ? savedInputs
      : [
          for (final day in days)
            for (final visit in day.visits)
              if (visit.kind != VisitKind.hotelStay)
                RoutePlaceInput(
                  place: visit.place,
                  day: visit.locked ? day.day : null,
                  startMinutes: visit.locked
                      ? visit.requestedStartMinutes ?? visit.startMinutes
                      : null,
                  locked: visit.locked,
                  preferences: visit.preferences,
                  kind: visit.kind,
                  suggestedMealType: visit.mealType == MealType.unspecified
                      ? null
                      : visit.mealType,
                ),
        ];

  final overrides = <RouteLegKey, RouteTravelMode>{};
  for (final value in _rows(
    snapshot['travelModeOverrides'],
    'travelModeOverrides',
  )) {
    final item = _map(value, 'travelModeOverrides[]');
    overrides[routeLegKey(
      day: _int(item['day'], 1),
      originId: _string(item['originId']),
      destinationId: _string(item['destinationId']),
    )] = _named(
      RouteTravelMode.values,
      item['mode'],
      RouteTravelMode.transit,
    );
  }

  return RouteItinerary(
    request: request,
    origin: origin,
    days: days,
    generatedAt: _date(snapshot['generatedAt'], 'generatedAt'),
    warnings: _strings(snapshot['warnings']),
    inputs: inputs,
    travelModeOverrides: overrides,
  );
}

RouteDay _day(Map<String, dynamic> data) {
  final origin = _stop(_map(data['origin'], 'day.origin'));
  return RouteDay(
    day: _int(data['day'], 1),
    date: _date(data['date'], 'day.date'),
    origin: origin,
    visits: [
      for (final value in _rows(data['visits'], 'day.visits'))
        _visit(_map(value, 'day.visits[]')),
    ],
    travelLegs: [
      for (final value in _rows(data['travelLegs'], 'day.travelLegs'))
        _leg(_map(value, 'day.travelLegs[]')),
    ],
    isValid: data['isValid'] != false,
    warnings: _strings(data['warnings']),
  );
}

RouteVisit _visit(Map<String, dynamic> data) => RouteVisit(
  place: _place(_map(data['place'], 'visit.place')),
  sequence: _int(data['sequence'], 0),
  arrivalMinutes: _int(data['arrivalMinutes'], 0),
  startMinutes: _int(data['startMinutes'], 0),
  endMinutes: _int(data['endMinutes'], 0),
  waitingMinutes: _int(data['waitingMinutes'], 0),
  stayMinutes: _int(data['stayMinutes'], 0),
  requestedStartMinutes: _optionalInt(data['requestedStartMinutes']),
  locked: data['locked'] == true,
  eventId: _optionalString(data['eventId']),
  kind: _named(VisitKind.values, data['kind'], VisitKind.activity),
  mealType: _named(MealType.values, data['mealType'], MealType.unspecified),
  preferences: _preferences(data['preferences']),
  information: _strings(data['information']),
);

RoutePlaceInput _input(Map<String, dynamic> data) => RoutePlaceInput(
  place: _place(_map(data['place'], 'input.place')),
  day: _optionalInt(data['day']),
  startMinutes: _optionalInt(data['startMinutes']),
  locked: data['locked'] == true,
  preferences: _preferences(data['preferences']),
  kind: _named(VisitKind.values, data['kind'], VisitKind.activity),
  suggestedMealType: _optionalNamed(MealType.values, data['suggestedMealType']),
);

TravelLeg _leg(Map<String, dynamic> data) {
  final schedule = _map(data['schedule'], 'leg.schedule');
  final routeData = data['route'];
  return TravelLeg(
    origin: _stop(_map(data['origin'], 'leg.origin')),
    destination: _stop(_map(data['destination'], 'leg.destination')),
    requestedDeparture: _date(data['requestedDeparture'], 'requestedDeparture'),
    travelMode: _named(
      RouteTravelMode.values,
      data['travelMode'],
      RouteTravelMode.transit,
    ),
    routeProvider:
        _optionalNamed(RouteProvider.values, data['routeProvider']) ??
        (data['sourceLabel'] == 'Google Maps（TDX 備援）'
            ? RouteProvider.google
            : null),
    errorMessage: _optionalString(data['errorMessage']),
    schedule: ScheduledVisit(
      departureMinutes: _int(schedule['departureMinutes'], 0),
      arrivalMinutes: _int(schedule['arrivalMinutes'], 0),
      visitStartMinutes: _int(schedule['visitStartMinutes'], 0),
      visitEndMinutes: _int(schedule['visitEndMinutes'], 0),
      waitingMinutes: _int(schedule['waitingMinutes'], 0),
      stayMinutes: _int(schedule['stayMinutes'], 0),
    ),
    route: routeData == null ? null : _route(_map(routeData, 'leg.route')),
  );
}

TdxRoute _route(Map<String, dynamic> data) => TdxRoute(
  transfers: _int(data['transfers'], 0),
  travelTime: _int(data['travelTime'], 0),
  startTime: _optionalDate(data['startTime']),
  endTime: _optionalDate(data['endTime']),
  distanceMeters: _optionalInt(data['distanceMeters']),
  sections: [
    for (final value in _rows(data['sections'], 'route.sections'))
      _section(_map(value, 'route.sections[]')),
  ],
);

RouteSection _section(Map<String, dynamic> data) => RouteSection(
  mode: _string(data['mode']),
  lineName: _optionalString(data['lineName']),
  destination: _optionalString(data['destination']),
  departureTitle: _optionalString(data['departureTitle']),
  arrivalTitle: _optionalString(data['arrivalTitle']),
  departureTime: _optionalString(data['departureTime']),
  arrivalTime: _optionalString(data['arrivalTime']),
  travelTime: _int(data['travelTime'], 0),
  stopCount: _int(data['stopCount'], 0),
  intermediateStops: _strings(data['intermediateStops']),
  operatorCode: _optionalString(data['operatorCode']),
  agencyId: _optionalString(data['agencyId']),
  serviceId: _optionalString(data['serviceId']),
  routeId: _optionalString(data['routeId']),
  city: _optionalString(data['city']),
  departureStopId: _optionalString(data['departureStopId']),
  arrivalStopId: _optionalString(data['arrivalStopId']),
  departureLatitude: _optionalDouble(data['departureLatitude']),
  departureLongitude: _optionalDouble(data['departureLongitude']),
  arrivalLatitude: _optionalDouble(data['arrivalLatitude']),
  arrivalLongitude: _optionalDouble(data['arrivalLongitude']),
  scheduledDeparture: _optionalDate(data['scheduledDeparture']),
  scheduledArrival: _optionalDate(data['scheduledArrival']),
);

RouteStop _stop(Map<String, dynamic> data) => RouteStop(
  id: _string(data['id']),
  name: _string(data['name']),
  latitude: _double(data['latitude'], 0),
  longitude: _double(data['longitude'], 0),
  county: _string(data['county']),
  stayDurationMinutes: _int(data['stayDurationMinutes'], 60),
  earliestTimeMinutes: _optionalInt(data['earliestTimeMinutes']),
  latestTimeMinutes: _optionalInt(data['latestTimeMinutes']),
  priorityScore: _double(data['priorityScore'], 1),
);

Place _place(Map<String, dynamic> data) => Place(
  id: _string(data['id']),
  name: _string(data['name']),
  category: _string(data['category']),
  description: _string(data['description']),
  address: _string(data['address']),
  latitude: _double(data['latitude'], 0),
  longitude: _double(data['longitude'], 0),
  image: _string(data['image']),
  type: _named(PlaceType.values, data['type'], PlaceType.attraction),
  county: _string(data['county']),
  district: _string(data['district']),
  openingHoursRaw: _string(data['openingHoursRaw']),
  openingHours: _strings(data['openingHours']),
  openingHoursProvided: data['openingHoursProvided'] is bool
      ? data['openingHoursProvided'] as bool
      : null,
  phone: _string(data['phone']),
  website: _string(data['website']),
  stayTime: _int(data['stayTime'], 60),
  rating: _double(data['rating'], 0),
  tags: _strings(data['tags']),
  price_level: _int(data['priceLevel'], 0),
  openMinutes: _int(data['openMinutes'], 0),
  closeMinutes: _int(data['closeMinutes'], 1440),
);

VisitPreferences _preferences(Object? value) {
  if (value == null) return const VisitPreferences();
  final data = _map(value, 'preferences');
  final hotel = data['hotelStay'];
  final hotelData = hotel == null ? null : _map(hotel, 'preferences.hotelStay');
  return VisitPreferences(
    mealType: _named(MealType.values, data['mealType'], MealType.unspecified),
    durationMinutes: _optionalInt(data['durationMinutes']),
    mealWindowStart: _optionalInt(data['mealWindowStart']),
    mealWindowEnd: _optionalInt(data['mealWindowEnd']),
    hotelStay: hotelData == null
        ? null
        : HotelStay(
            checkInDay: _int(hotelData['checkInDay'], 1),
            checkOutDay: _int(hotelData['checkOutDay'], 2),
            checkInFromMinutes: _optionalInt(hotelData['checkInFromMinutes']),
          ),
  );
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('行程快照缺少 $field');
  return Map<String, dynamic>.from(value);
}

List<dynamic> _rows(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List) throw FormatException('行程快照的 $field 格式不正確');
  return value;
}

String _string(Object? value) => value?.toString() ?? '';
String? _optionalString(Object? value) => value?.toString();
int _int(Object? value, int fallback) => _optionalInt(value) ?? fallback;
int? _optionalInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
double _double(Object? value, double fallback) =>
    _optionalDouble(value) ?? fallback;
double? _optionalDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
List<String> _strings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];
DateTime _date(Object? value, String field) =>
    _optionalDate(value) ?? (throw FormatException('行程快照缺少 $field'));
DateTime? _optionalDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '');
T _named<T extends Enum>(List<T> values, Object? value, T fallback) =>
    _optionalNamed(values, value) ?? fallback;
T? _optionalNamed<T extends Enum>(List<T> values, Object? value) {
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}
