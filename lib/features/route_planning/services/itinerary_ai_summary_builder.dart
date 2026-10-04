import '../models/route_itinerary.dart';

class ItineraryAiSummaryBuilder {
  const ItineraryAiSummaryBuilder._();

  static Map<String, dynamic> build(RouteItinerary itinerary) {
    return {
      'title': itinerary.request.title,
      'location': itinerary.request.locationLabel,
      'locations': itinerary.request.locations,
      'dayCount': itinerary.days.length,
      'startDate': _formatDate(itinerary.request.startDate),
      'endDate': _formatDate(itinerary.request.endDate),

      'days': itinerary.days.map((day) {
        return {
          'day': day.day,
          'date': _formatDate(day.date),

          'places': day.visits.map((visit) {
            return {
              'id': visit.place.id,
              'name': visit.place.name,
              'type': visit.place.type.name,
              'category': visit.place.category,
              'startMinutes': visit.startMinutes,
              'endMinutes': visit.endMinutes,
              'stayMinutes': visit.stayMinutes,
              'locked': visit.locked,
              'kind': visit.kind.name,
            };
          }).toList(),

          'travelLegs': day.travelLegs.map((leg) {
            return {
              'originName': leg.origin.name,
              'destinationName': leg.destination.name,
              'travelMode': leg.travelMode.name,
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
