import '../models/tdx_route.dart';

class TdxRouteRanker {
  final int maximumSingleWalkSeconds;
  final int transferPenaltySeconds;
  final double walkingPenaltyFactor;

  const TdxRouteRanker({
    this.maximumSingleWalkSeconds = 40 * 60,
    this.transferPenaltySeconds = 5 * 60,
    this.walkingPenaltyFactor = 0.75,
  });

  List<TdxRoute> rank(Iterable<TdxRoute> routes, {int limit = 10}) {
    final uniqueRoutes = _removeExactDuplicates(routes);
    final candidates = uniqueRoutes
        .where((route) => !_isPureWalking(route))
        .toList();
    if (candidates.isEmpty) {
      final walkingRoutes = uniqueRoutes
        ..sort(
          (first, second) =>
              _effectiveDuration(first).compareTo(_effectiveDuration(second)),
        );
      return walkingRoutes.take(limit).toList();
    }

    final reasonableWalking = candidates
        .where(
          (route) => _maximumWalkSeconds(route) <= maximumSingleWalkSeconds,
        )
        .toList();
    final ranked = reasonableWalking.isEmpty ? candidates : reasonableWalking;
    ranked.sort((first, second) => _score(first).compareTo(_score(second)));
    return ranked.take(limit).toList();
  }

  List<TdxRoute> _removeExactDuplicates(Iterable<TdxRoute> routes) {
    final seenSignatures = <String>{};
    return routes.where((route) {
      final signature = [
        route.startTime?.toIso8601String() ?? '',
        route.endTime?.toIso8601String() ?? '',
        route.travelTime,
        route.transfers,
        ...route.sections.map(
          (section) => [
            section.mode,
            section.lineName ?? '',
            section.departureTime ?? '',
            section.arrivalTime ?? '',
            section.departureTitle ?? '',
            section.arrivalTitle ?? '',
          ].join(':'),
        ),
      ].join('|');
      return seenSignatures.add(signature);
    }).toList();
  }

  double _score(TdxRoute route) {
    return _effectiveDuration(route) +
        _totalWalkSeconds(route) * walkingPenaltyFactor +
        route.transfers * transferPenaltySeconds;
  }

  int _effectiveDuration(TdxRoute route) {
    final startTime = route.startTime;
    final endTime = route.endTime;
    if (startTime != null && endTime != null && endTime.isAfter(startTime)) {
      return endTime.difference(startTime).inSeconds;
    }
    return route.travelTime;
  }

  int _totalWalkSeconds(TdxRoute route) {
    return route.sections
        .where((section) => _isWalkMode(section.mode))
        .fold(0, (total, section) => total + section.travelTime);
  }

  int _maximumWalkSeconds(TdxRoute route) {
    return route.sections.where((section) => _isWalkMode(section.mode)).fold(
      0,
      (maximum, section) {
        return section.travelTime > maximum ? section.travelTime : maximum;
      },
    );
  }

  bool _isPureWalking(TdxRoute route) {
    return route.sections.isNotEmpty &&
        route.sections.every((section) => _isWalkMode(section.mode));
  }

  bool _isWalkMode(String mode) {
    final normalized = mode.toLowerCase();
    return normalized == 'pedestrian' ||
        normalized == 'walking' ||
        normalized == 'walk';
  }
}
