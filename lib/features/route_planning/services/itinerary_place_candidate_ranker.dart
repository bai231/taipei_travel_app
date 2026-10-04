import 'dart:math';

import '../../../models/place.dart';
import '../models/route_itinerary.dart';
import 'itinerary_place_resolver.dart';

class ItineraryPlaceCandidateRanker {
  const ItineraryPlaceCandidateRanker();

  List<ItineraryPlaceMatch> rank({
    required List<ItineraryPlaceMatch> matches,
    required RouteItinerary itinerary,
    int? targetDay,
  }) {
    final relevantPlaces = _relevantItineraryPlaces(
      itinerary: itinerary,
      targetDay: targetDay,
    );

    final existingCategories = relevantPlaces
        .map((place) => place.category)
        .where((category) => category.trim().isNotEmpty)
        .toList();

    final ranked = matches.map((match) {
      final reasons = <String>[match.reason];

      var score = match.score;
      final place = match.place;

      score += _ratingScore(place, reasons);

      score += _distanceScore(
        place: place,
        existingPlaces: relevantPlaces,
        reasons: reasons,
      );

      score += _diversityScore(
        place: place,
        existingCategories: existingCategories,
        reasons: reasons,
      );

      score += _budgetScore(
        place: place,
        budgetLevel: itinerary.request.budget_level,
        reasons: reasons,
      );

      return ItineraryPlaceMatch(
        place: place,
        score: score,
        reason: reasons.join('；'),
      );
    }).toList();

    ranked.sort((first, second) {
      final scoreComparison = second.score.compareTo(first.score);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final ratingComparison = second.place.rating.compareTo(
        first.place.rating,
      );

      if (ratingComparison != 0) {
        return ratingComparison;
      }

      return first.place.name.compareTo(second.place.name);
    });

    return ranked;
  }

  List<Place> _relevantItineraryPlaces({
    required RouteItinerary itinerary,
    required int? targetDay,
  }) {
    if (targetDay != null) {
      final matchingDays = itinerary.days.where((day) => day.day == targetDay);

      if (matchingDays.isNotEmpty) {
        return matchingDays.first.visits.map((visit) => visit.place).toList();
      }
    }

    return [
      for (final day in itinerary.days)
        for (final visit in day.visits) visit.place,
    ];
  }

  double _ratingScore(Place place, List<String> reasons) {
    if (place.rating <= 0) {
      return 0;
    }

    final bonus = place.rating.clamp(0, 5) * 2;

    reasons.add('景點評分 ${place.rating.toStringAsFixed(1)}');

    return bonus.toDouble();
  }

  double _distanceScore({
    required Place place,
    required List<Place> existingPlaces,
    required List<String> reasons,
  }) {
    if (existingPlaces.isEmpty || !_hasUsableCoordinates(place)) {
      return 0;
    }

    final distances = existingPlaces
        .where(_hasUsableCoordinates)
        .map((existing) => _distanceKm(place, existing))
        .toList();

    if (distances.isEmpty) {
      return 0;
    }

    final nearestDistance = distances.reduce(min);

    if (nearestDistance <= 1) {
      reasons.add('距離既有景點約 1 公里內');
      return 25;
    }

    if (nearestDistance <= 3) {
      reasons.add('距離既有景點約 3 公里內');
      return 18;
    }

    if (nearestDistance <= 8) {
      reasons.add('距離既有景點約 8 公里內');
      return 10;
    }

    if (nearestDistance <= 15) {
      reasons.add('距離既有景點尚可');
      return 4;
    }

    if (nearestDistance > 30) {
      reasons.add('距離既有景點較遠');
      return -10;
    }

    return 0;
  }

  double _diversityScore({
    required Place place,
    required List<String> existingCategories,
    required List<String> reasons,
  }) {
    if (place.category.trim().isEmpty) {
      return 0;
    }

    final sameCategoryCount = existingCategories
        .where((category) => category == place.category)
        .length;

    if (sameCategoryCount == 0) {
      reasons.add('增加行程類型多樣性');
      return 8;
    }

    if (sameCategoryCount >= 2) {
      reasons.add('當日已有多個相同類型景點');
      return -5;
    }

    return 0;
  }

  double _budgetScore({
    required Place place,
    required int budgetLevel,
    required List<String> reasons,
  }) {
    if (place.price_level <= 0 || budgetLevel <= 0) {
      return 0;
    }

    if (place.price_level <= budgetLevel) {
      reasons.add('符合預算等級');
      return 5;
    }

    final difference = place.price_level - budgetLevel;

    reasons.add('價格等級高於預算');

    return -5.0 * difference;
  }

  bool _hasUsableCoordinates(Place place) {
    return place.latitude.isFinite &&
        place.longitude.isFinite &&
        place.latitude.abs() <= 90 &&
        place.longitude.abs() <= 180 &&
        !(place.latitude == 0 && place.longitude == 0);
  }

  double _distanceKm(Place first, Place second) {
    const earthRadiusKm = 6371.0;

    final firstLatitude = _toRadians(first.latitude);

    final secondLatitude = _toRadians(second.latitude);

    final latitudeDifference = _toRadians(second.latitude - first.latitude);

    final longitudeDifference = _toRadians(second.longitude - first.longitude);

    final a =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(firstLatitude) *
            cos(secondLatitude) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}
