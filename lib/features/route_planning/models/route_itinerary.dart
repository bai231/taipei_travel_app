import '../../../algorithm/route_optimizer.dart';
import '../../../models/place.dart';
import '../../../models/trip_request.dart';
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
    // 1. 還原 Request
    final req = (snapshot['request'] as Map<String, dynamic>?) ?? {};
    final request = TripRequest(
      title: req['title']?.toString() ?? '行程',
      startDate: DateTime.tryParse(req['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(req['endDate']?.toString() ?? '') ?? DateTime.now(),
      location: req['location']?.toString() ?? '',
      people: req['people'] is int ? req['people'] as int : 1,
      budget_level: req['budgetLevel'] is int ? req['budgetLevel'] as int : 1,
      preferences: List<String>.from(req['preferences'] ?? const []),
      aiPrompt: req['aiPrompt'].toString(),
    );

    // 2. 還原出發點 Origin
    final originMap = (snapshot['origin'] as Map<String, dynamic>?) ?? {};
    final originStop = RouteStop(
      id: originMap['id']?.toString() ?? 'origin',
      name: originMap['name']?.toString() ?? '出發點',
      latitude: (originMap['latitude'] as num?)?.toDouble() ?? 25.033,
      longitude: (originMap['longitude'] as num?)?.toDouble() ?? 121.565,
      county: originMap['county']?.toString() ?? '',
      stayDurationMinutes: originMap['stayDurationMinutes'] ?? 0,
      earliestTimeMinutes: originMap['earliestTimeMinutes'] ?? 0,
      latestTimeMinutes: originMap['latestTimeMinutes'] ?? 1440,
      priorityScore: originMap['priorityScore'] ?? 0,
    );

    // 3. 還原每日行程 (days -> RouteDay)
    final rawDays = (snapshot['days'] as List<dynamic>?) ?? const [];
    final List<RouteDay> days = rawDays.map<RouteDay>((d) {
      final dayMap = d as Map<String, dynamic>;

      // 還原當日各站點 visits
      final rawVisits = (dayMap['visits'] as List<dynamic>?) ?? const [];
      final visits = rawVisits.map<RouteVisit>((v) {
        final vMap = v as Map<String, dynamic>;
        final pMap = (vMap['place'] as Map<String, dynamic>?) ?? {};

        final place = Place(
          id: pMap['id']?.toString() ?? '',
          name: pMap['name']?.toString() ?? '',
          category: pMap['category']?.toString() ?? '',
          description: pMap['description']?.toString() ?? '',
          address: pMap['address']?.toString() ?? '',
          latitude: (pMap['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (pMap['longitude'] as num?)?.toDouble() ?? 0.0,
          image: pMap['image']?.toString() ?? '',
          county: pMap['county']?.toString() ?? '',
          stayTime: (pMap['stayTime'] as num?)?.toInt() ?? 60,
          rating: (pMap['rating'] as num?)?.toDouble() ?? 4.5,
          tags: List<String>.from(pMap['tags'] ?? const []),
          //estimatedCost: (pMap['estimatedCost'] as num?)?.toDouble() ?? 0.0,
          price_level: (pMap['priceLevel'] ?? pMap['price_level'] as num?)?.toInt() ?? 1,
          openMinutes: (pMap['openMinutes'] as num?)?.toInt() ?? 540,
          closeMinutes: (pMap['closeMinutes'] as num?)?.toInt() ?? 1080,
        );

        // 整理 information（相容 List<dynamic> 或字串）
        final rawInfo = vMap['information'];
        final List<String> infoList = rawInfo is List
            ? rawInfo.map((e) => e.toString()).toList()
            : (rawInfo != null && rawInfo.toString().isNotEmpty)
                ? [rawInfo.toString()]
                : const [];

        return RouteVisit(
          place: place,
          sequence: (vMap['sequence'] as num?)?.toInt() ?? 0,
          arrivalMinutes: (vMap['arrivalMinutes'] as num?)?.toInt() ?? 540,
          startMinutes: (vMap['startMinutes'] as num?)?.toInt() ?? 540,
          endMinutes: (vMap['endMinutes'] as num?)?.toInt() ?? 600,
          waitingMinutes: (vMap['waitingMinutes'] as num?)?.toInt() ?? 0,
          stayMinutes: (vMap['stayMinutes'] as num?)?.toInt() ?? 60,
          requestedStartMinutes: (vMap['requestedStartMinutes'] as num?)?.toInt(),
          locked: vMap['locked'] ?? false,
          eventId: vMap['eventId']?.toString(),
          information: infoList,
        );
      }).toList();

      return RouteDay(
        day: dayMap['day'] ?? 1,
        date: DateTime.tryParse(dayMap['date']?.toString() ?? '') ?? DateTime.now(),
        origin: originStop,
        visits: visits,
        travelLegs: const [],
        isValid: dayMap['isValid'] ?? true,
        warnings: List<String>.from(dayMap['warnings'] ?? const []),
      );
    }).toList();

    return RouteItinerary(
      request: request,
      origin: originStop,
      days: days,
      generatedAt: DateTime.tryParse(snapshot['generatedAt']?.toString() ?? '') ?? DateTime.now(),
      warnings: List<String>.from(snapshot['warnings'] ?? const []),
    );
  }
}
