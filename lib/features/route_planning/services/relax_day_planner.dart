import 'dart:math';

import '../../../models/place.dart';
import '../models/route_itinerary.dart';
import '../models/route_visit.dart';

class RelaxDayPlan {
  final int day;
  final Place? placeToRemove;
  final String explanation;
  final String? error;

  const RelaxDayPlan({
    required this.day,
    this.placeToRemove,
    required this.explanation,
    this.error,
  });

  bool get canApply {
    return placeToRemove != null && error == null;
  }
}

class RelaxDayPlanner {
  const RelaxDayPlanner();

  RelaxDayPlan createPlan({
    required RouteItinerary itinerary,
    required int day,
  }) {
    final matchingDays = itinerary.days.where((item) => item.day == day);

    if (matchingDays.isEmpty) {
      return RelaxDayPlan(
        day: day,
        explanation: '',
        error: '目前行程中找不到 Day $day。',
      );
    }

    final routeDay = matchingDays.first;

    final mustVisitNames =
        itinerary.request.parsedPreference?.mustVisitPlaceNames
            .map(_normalizeName)
            .toSet() ??
        <String>{};

    final candidates = <_RelaxCandidate>[];

    for (var index = 0; index < routeDay.visits.length; index++) {
      final visit = routeDay.visits[index];

      if (!_canRemove(visit, mustVisitNames)) {
        continue;
      }

      final detourDistance = _calculateDetourDistance(
        visits: routeDay.visits,
        index: index,
      );

      final burdenScore = visit.stayMinutes.toDouble() + detourDistance * 12;

      candidates.add(
        _RelaxCandidate(
          visit: visit,
          detourDistanceKm: detourDistance,
          burdenScore: burdenScore,
        ),
      );
    }

    if (candidates.isEmpty) {
      return RelaxDayPlan(
        day: day,
        explanation: '',
        error:
            'Day $day 沒有可安全移除的一般景點。'
            '鎖定、必去、餐廳及住宿項目都會被保留。',
      );
    }

    candidates.sort(
      (first, second) => second.burdenScore.compareTo(first.burdenScore),
    );

    final selected = candidates.first;

    return RelaxDayPlan(
      day: day,
      placeToRemove: selected.visit.place,
      explanation: _buildExplanation(selected),
    );
  }

  bool _canRemove(RouteVisit visit, Set<String> mustVisitNames) {
    if (visit.locked) {
      return false;
    }

    if (visit.place.type != PlaceType.attraction) {
      return false;
    }

    if (mustVisitNames.contains(_normalizeName(visit.place.name))) {
      return false;
    }

    return true;
  }

  double _calculateDetourDistance({
    required List<RouteVisit> visits,
    required int index,
  }) {
    final current = visits[index].place;

    final previous = index > 0 ? visits[index - 1].place : null;

    final next = index < visits.length - 1 ? visits[index + 1].place : null;

    if (previous != null && next != null) {
      final throughCurrent =
          _distanceKm(previous, current) + _distanceKm(current, next);

      final direct = _distanceKm(previous, next);

      return max(0, throughCurrent - direct);
    }

    if (previous != null) {
      return _distanceKm(previous, current);
    }

    if (next != null) {
      return _distanceKm(current, next);
    }

    return 0;
  }

  double _distanceKm(Place first, Place second) {
    if (!_hasUsableCoordinates(first) || !_hasUsableCoordinates(second)) {
      return 0;
    }

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

  bool _hasUsableCoordinates(Place place) {
    return place.latitude.isFinite &&
        place.longitude.isFinite &&
        place.latitude.abs() <= 90 &&
        place.longitude.abs() <= 180 &&
        !(place.latitude == 0 && place.longitude == 0);
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  String _buildExplanation(_RelaxCandidate candidate) {
    final visit = candidate.visit;
    final distance = candidate.detourDistanceKm;

    if (distance >= 0.5) {
      return '建議移除「${visit.place.name}」，'
          '可減少約 ${visit.stayMinutes} 分鐘停留，'
          '並減少約 ${distance.toStringAsFixed(1)} 公里的繞路。';
    }

    return '建議移除「${visit.place.name}」，'
        '可減少約 ${visit.stayMinutes} 分鐘的行程安排。';
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }
}

class _RelaxCandidate {
  final RouteVisit visit;
  final double detourDistanceKm;
  final double burdenScore;

  const _RelaxCandidate({
    required this.visit,
    required this.detourDistanceKm,
    required this.burdenScore,
  });
}
