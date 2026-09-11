import '../algorithm/route_optimizer.dart';
import '../features/route_planning/models/route_itinerary.dart';
import '../models/place.dart';
import '../models/visit_preferences.dart';

/// Versioned display snapshot, independent of the current place catalog.
/// List order is authoritative; minutes are offsets from each day's date.
Map<String, dynamic> itinerarySnapshot(RouteItinerary itinerary) {
  final request = itinerary.request;
  return {
    'schemaVersion': 1,
    'timeZone': 'Asia/Taipei',
    'generatedAt': itinerary.generatedAt.toIso8601String(),
    'request': {
      'title': request.title,
      'startDate': request.startDate.toIso8601String(),
      'endDate': request.endDate.toIso8601String(),
      'location': request.location,
      'people': request.people,
      'budget': request.budget,
      'preferences': request.preferences,
      'aiPrompt': request.aiPrompt,
    },
    'origin': _stop(itinerary.origin),
    'warnings': itinerary.warnings,
    'inputs': [
      for (final input in itinerary.inputs)
        {
          'place': _place(input.place),
          'day': input.day,
          'startMinutes': input.startMinutes,
          'locked': input.locked,
          'kind': input.kind.name,
          'suggestedMealType': input.suggestedMealType?.name,
          'preferences': _preferences(input.preferences),
        },
    ],
    'travelModeOverrides': [
      for (final entry in itinerary.travelModeOverrides.entries)
        {
          'day': entry.key.day,
          'originId': entry.key.originId,
          'destinationId': entry.key.destinationId,
          'mode': entry.value.name,
        },
    ],
    'days': [
      for (final day in itinerary.days)
        {
          'day': day.day,
          'date': day.date.toIso8601String(),
          'origin': _stop(day.origin),
          'isValid': day.isValid,
          'warnings': day.warnings,
          'visits': [
            for (final visit in day.visits)
              {
                'place': _place(visit.place),
                'sequence': visit.sequence,
                'arrivalMinutes': visit.arrivalMinutes,
                'startMinutes': visit.startMinutes,
                'endMinutes': visit.endMinutes,
                'waitingMinutes': visit.waitingMinutes,
                'stayMinutes': visit.stayMinutes,
                'requestedStartMinutes': visit.requestedStartMinutes,
                'locked': visit.locked,
                'eventId': visit.eventId,
                'occurrenceId': visit.occurrenceId,
                'kind': visit.kind.name,
                'mealType': visit.mealType.name,
                'preferences': _preferences(visit.preferences),
                'information': visit.information,
              },
          ],
          'travelLegs': [
            for (final leg in day.travelLegs)
              {
                'origin': _stop(leg.origin),
                'destination': _stop(leg.destination),
                'requestedDeparture': leg.requestedDeparture.toIso8601String(),
                'travelMode': leg.travelMode.name,
                'usesEstimatedTravelTime': leg.usesEstimatedTravelTime,
                'sourceLabel': leg.routeSourceLabel,
                'errorMessage': leg.errorMessage,
                'schedule': {
                  'departureMinutes': leg.schedule.departureMinutes,
                  'arrivalMinutes': leg.schedule.arrivalMinutes,
                  'visitStartMinutes': leg.schedule.visitStartMinutes,
                  'visitEndMinutes': leg.schedule.visitEndMinutes,
                  'waitingMinutes': leg.schedule.waitingMinutes,
                  'stayMinutes': leg.schedule.stayMinutes,
                },
                'route': leg.route == null
                    ? null
                    : {
                        'transfers': leg.route!.transfers,
                        'travelTime': leg.route!.travelTime,
                        'startTime': leg.route!.startTime?.toIso8601String(),
                        'endTime': leg.route!.endTime?.toIso8601String(),
                        'distanceMeters': leg.route!.distanceMeters,
                        'sections': [
                          for (final section in leg.route!.sections)
                            {
                              'mode': section.mode,
                              'lineName': section.lineName,
                              'destination': section.destination,
                              'departureTitle': section.departureTitle,
                              'arrivalTitle': section.arrivalTitle,
                              'departureTime': section.departureTime,
                              'arrivalTime': section.arrivalTime,
                              'travelTime': section.travelTime,
                              'stopCount': section.stopCount,
                              'intermediateStops': section.intermediateStops,
                            },
                        ],
                      },
              },
          ],
        },
    ],
  };
}

Map<String, dynamic> _stop(RouteStop stop) => {
  'id': stop.id,
  'name': stop.name,
  'latitude': stop.latitude,
  'longitude': stop.longitude,
  'county': stop.county,
  'stayDurationMinutes': stop.stayDurationMinutes,
  'earliestTimeMinutes': stop.earliestTimeMinutes,
  'latestTimeMinutes': stop.latestTimeMinutes,
  'priorityScore': stop.priorityScore,
};

Map<String, dynamic> _place(Place place) => {
  'id': place.id,
  'name': place.name,
  'type': place.type.name,
  'category': place.category,
  'description': place.description,
  'address': place.address,
  'latitude': place.latitude,
  'longitude': place.longitude,
  'image': place.image,
  'county': place.county,
  'openingHoursRaw': place.openingHoursRaw,
  'openingHoursProvided': place.openingHoursProvided,
  'stayTime': place.stayTime,
  'rating': place.rating,
  'tags': place.tags,
  'estimatedCost': place.estimatedCost,
  'openMinutes': place.openMinutes,
  'closeMinutes': place.closeMinutes,
};

Map<String, dynamic> _preferences(VisitPreferences value) => {
  'mealType': value.mealType.name,
  'durationMinutes': value.durationMinutes,
  'mealWindowStart': value.mealWindowStart,
  'mealWindowEnd': value.mealWindowEnd,
  'hotelStay': value.hotelStay == null
      ? null
      : {
          'checkInDay': value.hotelStay!.checkInDay,
          'checkOutDay': value.hotelStay!.checkOutDay,
          'checkInFromMinutes': value.hotelStay!.checkInFromMinutes,
        },
};
