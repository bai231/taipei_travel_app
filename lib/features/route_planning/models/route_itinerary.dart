import '../../../algorithm/route_optimizer.dart';
import '../../../models/place.dart';
import '../../../models/scheduled_visit.dart';
import '../../../models/tdx_route.dart';
import '../../../models/trip_place_constraint.dart';
import '../../../models/trip_request.dart';
import '../../../models/travel_preference.dart';
import '../../../models/visit_preferences.dart';
import 'route_day.dart';
import 'route_place_input.dart';
import 'route_travel_mode.dart';
import 'route_visit.dart';
import 'travel_leg.dart';

class RouteItinerary {
  final TripRequest request;
  final RouteStop origin;
  final List<RouteDay> days;
  final DateTime generatedAt;
  final List<String> warnings;
  final List<RoutePlaceInput> inputs;
  final Map<RouteLegKey, RouteTravelMode> travelModeOverrides;

  RouteItinerary({
    required this.request,
    required this.origin,
    required List<RouteDay> days,
    required this.generatedAt,
    List<String> warnings = const [],
    List<RoutePlaceInput> inputs = const [],
    Map<RouteLegKey, RouteTravelMode> travelModeOverrides = const {},
  })  : days = List.unmodifiable(days),
        warnings = List.unmodifiable(warnings),
        inputs = List.unmodifiable(inputs),
        travelModeOverrides = Map.unmodifiable(travelModeOverrides);

  RouteDay day(int dayNumber) {
    return days.firstWhere((day) => day.day == dayNumber);
  }

  // 🌟 將 Supabase 快照精確還原為強型別 RouteItinerary 物件
  factory RouteItinerary.fromSnapshot(Map<String, dynamic> snapshot) {
    final req = _snapshotMap(snapshot['request']);
    final rawInputs = _snapshotList(snapshot['inputs']);
    final inputs = rawInputs.map((value) {
      final input = _snapshotMap(value);
      final place = _placeFromSnapshot(input['place']);
      return RoutePlaceInput(
        place: place,
        day: _snapshotInt(input['day']),
        startMinutes: _snapshotInt(input['startMinutes']),
        locked: _snapshotBool(input['locked']),
        kind: _snapshotEnum(VisitKind.values, input['kind'], VisitKind.activity),
        suggestedMealType: _snapshotNullableEnum(
          MealType.values,
          input['suggestedMealType'],
        ),
        preferences: _visitPreferencesFromSnapshot(input['preferences']),
      );
    }).toList();
    final constraints = inputs
        .map((input) => TripPlaceConstraint(
              place: input.place,
              day: input.day,
              startMinutes: input.startMinutes,
              locked: input.locked,
              kind: input.kind,
              suggestedMealType: input.suggestedMealType,
              preferences: input.preferences,
            ))
        .toList();

    final request = TripRequest(
      title: req['title']?.toString() ?? '行程',
      startDate: DateTime.tryParse(req['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(req['endDate']?.toString() ?? '') ?? DateTime.now(),
      location: req['location']?.toString() ?? '',
      people: _snapshotInt(req['people']) ?? 1,
      budget_level: _snapshotInt(req['budgetLevel']) ?? 1,
      preferences: _snapshotStringList(req['preferences']),
      aiPrompt: req['aiPrompt']?.toString() ?? '',
      parsedPreference: req['parsedPreference'] is Map
          ? TravelPreference.fromJson(_snapshotMap(req['parsedPreference']))
          : null,
      selectedPlaces: constraints,
    );

    final originStop = _routeStopFromSnapshot(snapshot['origin']);

    final days = _snapshotList(snapshot['days']).map((value) {
      final dayMap = _snapshotMap(value);
      final dayOrigin = dayMap['origin'] == null
          ? originStop
          : _routeStopFromSnapshot(dayMap['origin']);
      final visits = _snapshotList(dayMap['visits']).map((value) {
        final visit = _snapshotMap(value);
        final place = _placeFromSnapshot(visit['place']);
        return RouteVisit(
          place: place,
          sequence: _snapshotInt(visit['sequence']) ?? 0,
          arrivalMinutes: _snapshotInt(visit['arrivalMinutes']) ?? 540,
          startMinutes: _snapshotInt(visit['startMinutes']) ?? 540,
          endMinutes: _snapshotInt(visit['endMinutes']) ?? 600,
          waitingMinutes: _snapshotInt(visit['waitingMinutes']) ?? 0,
          stayMinutes: _snapshotInt(visit['stayMinutes']) ?? 60,
          requestedStartMinutes: _snapshotInt(visit['requestedStartMinutes']),
          locked: _snapshotBool(visit['locked']),
          eventId: visit['eventId']?.toString(),
          kind: _snapshotEnum(VisitKind.values, visit['kind'], VisitKind.activity),
          mealType: _snapshotEnum(
            MealType.values,
            visit['mealType'],
            MealType.unspecified,
          ),
          preferences: _visitPreferencesFromSnapshot(visit['preferences']),
          information: _snapshotStringList(visit['information']),
        );
      }).toList();
      final travelLegs = _snapshotList(dayMap['travelLegs'])
          .map(_travelLegFromSnapshot)
          .toList();

      return RouteDay(
        day: _snapshotInt(dayMap['day']) ?? 1,
        date: DateTime.tryParse(dayMap['date']?.toString() ?? '') ?? DateTime.now(),
        origin: dayOrigin,
        visits: visits,
        travelLegs: travelLegs,
        isValid: _snapshotBool(dayMap['isValid'], fallback: true),
        warnings: _snapshotStringList(dayMap['warnings']),
      );
    }).toList();

    final travelModeOverrides = <RouteLegKey, RouteTravelMode>{};
    for (final value in _snapshotList(snapshot['travelModeOverrides'])) {
      final item = _snapshotMap(value);
      final mode = _snapshotNullableEnum(RouteTravelMode.values, item['mode']);
      final day = _snapshotInt(item['day']);
      if (mode == null || day == null) continue;
      travelModeOverrides[routeLegKey(
        day: day,
        originId: item['originId']?.toString() ?? '',
        destinationId: item['destinationId']?.toString() ?? '',
      )] = mode;
    }

    return RouteItinerary(
      request: request,
      origin: originStop,
      days: days,
      generatedAt: DateTime.tryParse(snapshot['generatedAt']?.toString() ?? '') ?? DateTime.now(),
      warnings: _snapshotStringList(snapshot['warnings']),
      inputs: inputs,
      travelModeOverrides: travelModeOverrides,
    );
  }
}

Map<String, dynamic> _snapshotMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _snapshotList(Object? value) =>
    value is List ? value : const <dynamic>[];

List<String> _snapshotStringList(Object? value) =>
    _snapshotList(value).map((item) => item.toString()).toList();

int? _snapshotInt(Object? value) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '');

double _snapshotDouble(Object? value, {double fallback = 0}) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? fallback;

bool _snapshotBool(Object? value, {bool fallback = false}) =>
    value is bool ? value : value is String ? value.toLowerCase() == 'true' : fallback;

T _snapshotEnum<T extends Enum>(List<T> values, Object? value, T fallback) {
  for (final item in values) {
    if (item.name == value?.toString()) return item;
  }
  return fallback;
}

T? _snapshotNullableEnum<T extends Enum>(List<T> values, Object? value) {
  if (value == null) return null;
  for (final item in values) {
    if (item.name == value.toString()) return item;
  }
  return null;
}

Place _placeFromSnapshot(Object? value) {
  final place = _snapshotMap(value);
  final tags = _snapshotStringList(place['tags']);
  return Place(
    id: place['id']?.toString() ?? '',
    name: place['name']?.toString() ?? '',
    type: _snapshotNullableEnum(PlaceType.values, place['type']) ??
        PlaceType.fromData(
          value: place['type'],
          name: place['name']?.toString() ?? '',
          category: place['category']?.toString() ?? '',
          tags: tags,
        ),
    category: place['category']?.toString() ?? '',
    description: place['description']?.toString() ?? '',
    address: place['address']?.toString() ?? '',
    latitude: _snapshotDouble(place['latitude']),
    longitude: _snapshotDouble(place['longitude']),
    image: place['image']?.toString() ?? '',
    county: place['county']?.toString() ?? '',
    district: place['district']?.toString() ?? '',
    openingHoursRaw: place['openingHoursRaw']?.toString() ?? '',
    openingHours: _snapshotStringList(place['openingHours']),
    openingHoursProvided: place['openingHoursProvided'] is bool
        ? place['openingHoursProvided'] as bool
        : null,
    phone: place['phone']?.toString() ?? '',
    website: place['website']?.toString() ?? '',
    stayTime: _snapshotInt(place['stayTime']) ?? 60,
    rating: _snapshotDouble(place['rating'], fallback: 4.5),
    tags: tags,
    price_level: _snapshotInt(place['priceLevel'] ?? place['price_level']) ?? 1,
    openMinutes: _snapshotInt(place['openMinutes']) ?? 540,
    closeMinutes: _snapshotInt(place['closeMinutes']) ?? 1080,
  );
}

VisitPreferences _visitPreferencesFromSnapshot(Object? value) {
  final preferences = _snapshotMap(value);
  final rawHotelStay = _snapshotMap(preferences['hotelStay']);
  final hotelStay = rawHotelStay.isEmpty
      ? null
      : HotelStay(
          checkInDay: _snapshotInt(rawHotelStay['checkInDay']) ?? 1,
          checkOutDay: _snapshotInt(rawHotelStay['checkOutDay']) ?? 2,
          checkInFromMinutes: _snapshotInt(rawHotelStay['checkInFromMinutes']),
        );
  return VisitPreferences(
    mealType: _snapshotEnum(
      MealType.values,
      preferences['mealType'],
      MealType.unspecified,
    ),
    durationMinutes: _snapshotInt(preferences['durationMinutes']),
    mealWindowStart: _snapshotInt(preferences['mealWindowStart']),
    mealWindowEnd: _snapshotInt(preferences['mealWindowEnd']),
    hotelStay: hotelStay,
  );
}

RouteStop _routeStopFromSnapshot(Object? value) {
  final stop = _snapshotMap(value);
  return RouteStop(
    id: stop['id']?.toString() ?? 'origin',
    name: stop['name']?.toString() ?? '出發點',
    latitude: _snapshotDouble(stop['latitude'], fallback: 25.033),
    longitude: _snapshotDouble(stop['longitude'], fallback: 121.565),
    county: stop['county']?.toString() ?? '',
    stayDurationMinutes: _snapshotInt(stop['stayDurationMinutes']) ?? 0,
    earliestTimeMinutes: _snapshotInt(stop['earliestTimeMinutes']),
    latestTimeMinutes: _snapshotInt(stop['latestTimeMinutes']),
    priorityScore: _snapshotDouble(stop['priorityScore'], fallback: 1),
  );
}

TravelLeg _travelLegFromSnapshot(Object? value) {
  final leg = _snapshotMap(value);
  final scheduleMap = _snapshotMap(leg['schedule']);
  final routeMap = _snapshotMap(leg['route']);
  final route = routeMap.isEmpty
      ? null
      : TdxRoute(
          transfers: _snapshotInt(routeMap['transfers']) ?? 0,
          travelTime: _snapshotInt(routeMap['travelTime']) ?? 0,
          startTime: DateTime.tryParse(routeMap['startTime']?.toString() ?? ''),
          endTime: DateTime.tryParse(routeMap['endTime']?.toString() ?? ''),
          distanceMeters: _snapshotInt(routeMap['distanceMeters']),
          sections: _snapshotList(routeMap['sections']).map((value) {
            final section = _snapshotMap(value);
            return RouteSection(
              mode: section['mode']?.toString() ?? 'transit',
              lineName: section['lineName']?.toString(),
              destination: section['destination']?.toString(),
              departureTitle: section['departureTitle']?.toString(),
              arrivalTitle: section['arrivalTitle']?.toString(),
              departureTime: section['departureTime']?.toString(),
              arrivalTime: section['arrivalTime']?.toString(),
              travelTime: _snapshotInt(section['travelTime']) ?? 0,
              stopCount: _snapshotInt(section['stopCount']) ?? 0,
              intermediateStops: _snapshotStringList(section['intermediateStops']),
            );
          }).toList(),
        );
  return TravelLeg(
    origin: _routeStopFromSnapshot(leg['origin']),
    destination: _routeStopFromSnapshot(leg['destination']),
    requestedDeparture: DateTime.tryParse(leg['requestedDeparture']?.toString() ?? '') ?? DateTime.now(),
    schedule: ScheduledVisit(
      departureMinutes: _snapshotInt(scheduleMap['departureMinutes']) ?? 540,
      arrivalMinutes: _snapshotInt(scheduleMap['arrivalMinutes']) ?? 540,
      visitStartMinutes: _snapshotInt(scheduleMap['visitStartMinutes']) ?? 540,
      visitEndMinutes: _snapshotInt(scheduleMap['visitEndMinutes']) ?? 600,
      waitingMinutes: _snapshotInt(scheduleMap['waitingMinutes']) ?? 0,
      stayMinutes: _snapshotInt(scheduleMap['stayMinutes']) ?? 60,
    ),
    route: route,
    errorMessage: leg['errorMessage']?.toString(),
    travelMode: _snapshotEnum(
      RouteTravelMode.values,
      leg['travelMode'],
      RouteTravelMode.transit,
    ),
  );
}
