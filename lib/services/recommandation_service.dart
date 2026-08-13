import '../models/place.dart';
import '../models/trip_request.dart';
import '../models/recommended_place.dart';

class RecommendService {
  List<RecommendedPlace> recommend(List<Place> places, TripRequest request) {
    final results = places.map((place) {
      double score = 0;

      // ① 偏好分數
      score += _calculatePreferenceScore(place, request);

      // ② 評比分數
      score += _calculateRatingScore(place);

      // ③ 預算分數
      score += _calculateBudgetScore(place, request);

      // ④ 時間分數
      score += _calculateTimeScore(place, request);

      return RecommendedPlace(place: place, score: score);
    }).toList();

    // 分數由高到低排序
    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }

  double _calculatePreferenceScore(Place place, TripRequest request) {
    if (request.preferences.isEmpty) {
      return 0;
    }

    int matched = 0;

    for (final preference in request.preferences) {
      if (place.tags.contains(preference)) {
        matched++;
      }
    }

    return (matched / request.preferences.length) * 40;
  }

  double _calculateRatingScore(Place place) {
    return (place.rating / 5.0) * 25;
  }

  double _calculateBudgetScore(Place place, TripRequest request) {
    // 每人每天的平均預算
    final dailyBudgetPerPerson = request.budget / request.people / request.days;

    // 假設 30% 的預算可以用於景點
    final attractionBudget = dailyBudgetPerPerson * 0.3;

    // 免費景點
    if (place.estimatedCost == 0) {
      return 20;
    }

    // 景點價格遠低於可接受預算
    if (place.estimatedCost <= attractionBudget) {
      return 20;
    }

    // 稍微超過預算
    if (place.estimatedCost <= attractionBudget * 1.5) {
      return 12;
    }

    // 明顯超過預算
    if (place.estimatedCost <= attractionBudget * 2) {
      return 5;
    }

    // 太貴
    return 0;
  }

  double _calculateTimeScore(Place place, TripRequest request) {
    // 假設一天可以安排 12 小時
    const availableMinutesPerDay = 12 * 60;

    // 景點停留時間太長
    if (place.stayTime > availableMinutesPerDay) {
      return 0;
    }

    // 1～3 小時是目前 Prototype 最理想的範圍
    if (place.stayTime >= 60 && place.stayTime <= 180) {
      return 15;
    }

    // 太短或太長，但仍然可以安排
    return 8;
  }
}
