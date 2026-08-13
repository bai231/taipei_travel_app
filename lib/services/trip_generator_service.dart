import '../models/place.dart';
import '../models/recommended_place.dart';
import '../models/trip_item.dart';
import '../models/generated_trip.dart';

class TripGeneratorService {
  static const int startMinutes = 9 * 60;
  static const int endMinutes = 21 * 60;

  static const int travelMinutes = 30;

  static const int maxPlacesPerDay = 4;

  static const int lunchStart = 12 * 60;
  static const int lunchEnd = 13 * 60;

  static const int dinnerStart = 18 * 60;
  static const int dinnerEnd = 19 * 60;

  GeneratedTrip generate(List<RecommendedPlace> recommendedPlaces, int days) {
    final List<TripItem> items = [];

    int currentDay = 1;
    int currentTime = startMinutes;
    int placesToday = 0;

    for (final recommended in recommendedPlaces) {
      final place = recommended.place;

      // 一天景點數量已達上限
      if (placesToday >= maxPlacesPerDay) {
        currentDay++;

        if (currentDay > days) {
          break;
        }

        currentTime = startMinutes;
        placesToday = 0;
      }

      int startTime = currentTime;

      // 如果碰到午餐或晚餐
      startTime = _adjustForMealTime(startTime, place.stayTime);

      // 檢查營業時間
      if (!_isWithinOpeningHours(startTime, place)) {
        // 嘗試下一個時間
        startTime = _findNextAvailableTime(startTime, place);
      }

      // 找不到可以安排的時間
      if (startTime == -1) {
        currentDay++;

        if (currentDay > days) {
          break;
        }

        currentTime = startMinutes;
        placesToday = 0;

        startTime = _findNextAvailableTime(currentTime, place);

        if (startTime == -1) {
          continue;
        }
      }

      final endTime = startTime + place.stayTime;

      // 確認不能超過一天結束時間
      if (endTime > endMinutes) {
        currentDay++;

        if (currentDay > days) {
          break;
        }

        currentTime = startMinutes;
        placesToday = 0;

        startTime = _findNextAvailableTime(currentTime, place);

        if (startTime == -1) {
          continue;
        }
      }

      final finalEndTime = startTime + place.stayTime;

      items.add(
        TripItem(
          place: place,
          day: currentDay,
          startMinutes: startTime,
          endMinutes: finalEndTime,
        ),
      );

      currentTime = finalEndTime + travelMinutes;

      placesToday++;
    }

    return GeneratedTrip(items: items);
  }

  int _adjustForMealTime(int start, int duration) {
    final end = start + duration;

    if (start < lunchEnd && end > lunchStart) {
      return lunchEnd;
    }

    if (start < dinnerEnd && end > dinnerStart) {
      return dinnerEnd;
    }

    return start;
  }

  bool _isWithinOpeningHours(int start, Place place) {
    final end = start + place.stayTime;

    return start >= place.openMinutes && end <= place.closeMinutes;
  }

  int _findNextAvailableTime(int start, Place place) {
    int current = start;

    // 嘗試目前時間
    if (_isWithinOpeningHours(current, place)) {
      return current;
    }

    // 嘗試午餐後
    if (current < lunchEnd) {
      current = lunchEnd;

      if (_isWithinOpeningHours(current, place)) {
        return current;
      }
    }

    // 嘗試晚餐後
    if (current < dinnerEnd) {
      current = dinnerEnd;

      if (_isWithinOpeningHours(current, place)) {
        return current;
      }
    }

    return -1;
  }
}
