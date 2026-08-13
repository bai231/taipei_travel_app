import '../models/recommended_place.dart';
import '../models/trip_item.dart';
import '../models/generated_trip.dart';

class TripGeneratorService {
  static const int startMinutes = 9 * 60; // 09:00

  static const int endMinutes = 21 * 60; // 21:00

  static const int travelMinutes = 30;

  GeneratedTrip generate(List<RecommendedPlace> recommendedPlaces, int days) {
    final List<TripItem> items = [];

    int currentDay = 1;

    int currentTime = startMinutes;

    for (final recommended in recommendedPlaces) {
      final place = recommended.place;

      final int requiredMinutes = place.stayTime + travelMinutes;

      // 如果今天放不下這個景點
      if (currentTime + requiredMinutes > endMinutes) {
        // 換到下一天
        currentDay++;

        currentTime = startMinutes;
      }

      // 已經沒有更多天數
      if (currentDay > days) {
        break;
      }

      final int startTime = currentTime;

      final int endTime = startTime + place.stayTime;

      items.add(
        TripItem(
          place: place,
          day: currentDay,
          startMinutes: startTime,
          endMinutes: endTime,
        ),
      );

      currentTime = endTime + travelMinutes;
    }

    return GeneratedTrip(items: items);
  }
}
