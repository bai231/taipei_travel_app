import 'place.dart';
import 'weather_alternative_strategy.dart';

class WeatherAlternativeCandidate {
  final Place place;
  final double score;
  final List<String> reasons;

  const WeatherAlternativeCandidate({
    required this.place,
    required this.score,
    required this.reasons,
  });
}

class WeatherResolvedReplacement {
  final WeatherAlternativeReplacement strategy;
  final WeatherItineraryPlaceSnapshot original;
  final List<WeatherAlternativeCandidate> candidates;

  const WeatherResolvedReplacement({
    required this.strategy,
    required this.original,
    required this.candidates,
  });
}

class WeatherItineraryPlaceSnapshot {
  final String occurrenceId;
  final String placeId;
  final String name;

  const WeatherItineraryPlaceSnapshot({
    required this.occurrenceId,
    required this.placeId,
    required this.name,
  });
}
