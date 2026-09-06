import '../models/place.dart';

class RouteStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String county;
  final int stayDurationMinutes;
  final int? earliestTimeMinutes;
  final int? latestTimeMinutes;
  final double priorityScore;

  const RouteStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.county = '',
    this.stayDurationMinutes = 60,
    this.earliestTimeMinutes,
    this.latestTimeMinutes,
    this.priorityScore = 1,
  });

  factory RouteStop.fromPlace(Place place, {double priorityScore = 1}) {
    return RouteStop(
      id: place.id,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      county: place.county,
      stayDurationMinutes: place.stayTime,
      earliestTimeMinutes: place.openMinutes,
      latestTimeMinutes: place.closeMinutes,
      priorityScore: priorityScore,
    );
  }
}

class OptimizationResult {
  final List<RouteStop> sortedStops;
  final int totalTimeMinutes;
  final bool isValid;

  const OptimizationResult({
    required this.sortedStops,
    required this.totalTimeMinutes,
    required this.isValid,
  });
}

class RouteOptimizer {
  OptimizationResult optimizeRoute({
    required List<RouteStop> stopsToVisit,
    required List<List<double>> durationMatrix,
    required int startTimeMinutes,
    List<double>? travelTimesFromStart,
    List<double>? travelTimesToEnd,
    List<double>? endPenaltyScores,
  }) {
    if (stopsToVisit.isEmpty) {
      return const OptimizationResult(
        sortedStops: [],
        totalTimeMinutes: 0,
        isValid: true,
      );
    }

    _validateDurationMatrix(stopsToVisit.length, durationMatrix);
    if (travelTimesFromStart != null &&
        travelTimesFromStart.length != stopsToVisit.length) {
      throw ArgumentError.value(
        travelTimesFromStart,
        'travelTimesFromStart',
        '起點交通時間必須與景點數量相同。',
      );
    }
    if (travelTimesToEnd != null &&
        travelTimesToEnd.length != stopsToVisit.length) {
      throw ArgumentError.value(
        travelTimesToEnd,
        'travelTimesToEnd',
        '終點交通時間必須與景點數量相同。',
      );
    }
    if (endPenaltyScores != null &&
        endPenaltyScores.length != stopsToVisit.length) {
      throw ArgumentError.value(
        endPenaltyScores,
        'endPenaltyScores',
        '終點懲罰分數必須與景點數量相同。',
      );
    }
    List<RouteStop> bestSequence = [];
    var minimumCost = double.infinity;
    var bestIsValid = false;
    var bestTotalDuration = 0;

    for (final permutation in _generatePermutations(stopsToVisit.length)) {
      var currentCost = 0.0;
      var currentTime = startTimeMinutes;
      var routeValid = true;

      for (var index = 0; index < permutation.length; index++) {
        final stopIndex = permutation[index];
        final stop = stopsToVisit[stopIndex];

        if (index == 0 && travelTimesFromStart != null) {
          final travelTime = travelTimesFromStart[stopIndex];
          currentTime += travelTime.round();
          currentCost += travelTime;
        } else if (index > 0) {
          final previousStopIndex = permutation[index - 1];
          final travelTime = durationMatrix[previousStopIndex][stopIndex];
          currentTime += travelTime.round();
          currentCost += travelTime;
        }

        if (stop.earliestTimeMinutes != null &&
            currentTime < stop.earliestTimeMinutes!) {
          final waitTime = stop.earliestTimeMinutes! - currentTime;
          currentTime += waitTime;
          currentCost += waitTime * 0.5;
        }

        if (stop.latestTimeMinutes != null &&
            currentTime > stop.latestTimeMinutes!) {
          routeValid = false;
          currentCost += 10000;
        }

        currentTime += stop.stayDurationMinutes;
        currentCost -= stop.priorityScore * 15;
      }

      if (travelTimesToEnd != null) {
        final endTravel = travelTimesToEnd[permutation.last];
        currentCost += endTravel;
        currentTime += endTravel.round();
      }
      if (endPenaltyScores != null) {
        currentCost += endPenaltyScores[permutation.last];
      }

      if ((routeValid && !bestIsValid) ||
          (routeValid == bestIsValid && currentCost < minimumCost)) {
        minimumCost = currentCost;
        bestSequence = permutation.map((index) => stopsToVisit[index]).toList();
        bestIsValid = routeValid;
        bestTotalDuration = currentTime - startTimeMinutes;
      }
    }

    return OptimizationResult(
      sortedStops: bestSequence,
      totalTimeMinutes: bestTotalDuration,
      isValid: bestIsValid,
    );
  }

  void _validateDurationMatrix(
    int stopCount,
    List<List<double>> durationMatrix,
  ) {
    if (durationMatrix.length != stopCount ||
        durationMatrix.any((row) => row.length != stopCount)) {
      throw ArgumentError.value(
        durationMatrix,
        'durationMatrix',
        '必須是與景點數量相同的 N x N 矩陣。',
      );
    }
  }

  List<List<int>> _generatePermutations(int length) {
    final permutations = <List<int>>[];
    final indexes = List.generate(length, (index) => index);

    void permute(int position) {
      if (position == indexes.length) {
        permutations.add(List.of(indexes));
        return;
      }

      for (var index = position; index < indexes.length; index++) {
        final current = indexes[position];
        indexes[position] = indexes[index];
        indexes[index] = current;
        permute(position + 1);
        indexes[index] = indexes[position];
        indexes[position] = current;
      }
    }

    permute(0);
    return permutations;
  }
}
