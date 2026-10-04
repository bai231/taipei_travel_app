import 'dart:math';

import '../models/place.dart';
import '../models/weather_alternative_candidate.dart';
import '../models/weather_alternative_strategy.dart';
import 'place_service.dart';
import 'weather_advisory_service.dart';
import 'weather_itinerary_impact_analyzer.dart';

class WeatherAlternativeCandidateService {
  final PlaceService _placeService;
  final WeatherItineraryImpactAnalyzer _impactAnalyzer;

  WeatherAlternativeCandidateService({
    PlaceService? placeService,
    WeatherItineraryImpactAnalyzer? impactAnalyzer,
  }) : _placeService = placeService ?? PlaceService(),
       _impactAnalyzer = impactAnalyzer ?? WeatherItineraryImpactAnalyzer();

  Future<List<WeatherResolvedReplacement>> resolve({
    required WeatherAlternativeStrategy strategy,
    required WeatherIndoorItineraryRequest request,
    int candidateLimit = 5,
  }) async {
    final catalog = await _placeService.getPlaces();

    final placesById = {for (final place in catalog) place.id: place};

    final existingPlaceIds = request.remainingPlaces
        .map((place) => place.placeId)
        .toSet();

    final requestPlacesByOccurrenceId = {
      for (final place in request.remainingPlaces) place.occurrenceId: place,
    };

    final results = <WeatherResolvedReplacement>[];

    for (final replacement in strategy.replacements) {
      final originalRequestPlace =
          requestPlacesByOccurrenceId[replacement.targetOccurrenceId];

      if (originalRequestPlace == null) {
        continue;
      }

      final originalPlace = placesById[originalRequestPlace.placeId];

      if (replacement.decision == WeatherAlternativeDecision.keep) {
        results.add(
          WeatherResolvedReplacement(
            strategy: replacement,
            original: WeatherItineraryPlaceSnapshot(
              occurrenceId: originalRequestPlace.occurrenceId,
              placeId: originalRequestPlace.placeId,
              name: originalRequestPlace.name,
            ),
            candidates: const [],
          ),
        );

        continue;
      }

      final candidates = <WeatherAlternativeCandidate>[];

      for (final place in catalog) {
        if (place.type != PlaceType.attraction) continue;

        if (existingPlaceIds.contains(place.id)) continue;

        if (!PlaceService.hasUsableCoordinates(place)) {
          continue;
        }

        final placeCounty = _normalize(PlaceService.countyFor(place));

        final preferredCounty = _normalize(replacement.preferredCounty ?? '');

        if (preferredCounty.isNotEmpty && placeCounty != preferredCounty) {
          continue;
        }

        final normalizedTags = place.tags.map(_normalize).toSet();

        final excludedTags = replacement.excludedTags.map(_normalize).toSet();

        if (normalizedTags.intersection(excludedTags).isNotEmpty) {
          continue;
        }

        final exposure = _impactAnalyzer.classify(place);

        // 天氣備案第一版只接受室內景點。
        if (exposure != WeatherExposure.indoor) {
          continue;
        }

        final categoryMatched = replacement.preferredCategories
            .map(_normalize)
            .contains(_normalize(place.category));

        final preferredTags = replacement.preferredTags.map(_normalize).toSet();

        final matchedTags = normalizedTags.intersection(preferredTags);

        if (!categoryMatched && matchedTags.isEmpty) {
          continue;
        }

        if (!_fitsOpeningHours(
          place: place,
          date: request.dayDate,
          startMinutes: originalRequestPlace.startMinutes,
          endMinutes: originalRequestPlace.endMinutes,
        )) {
          continue;
        }

        final reasons = <String>[];
        var score = 0.0;

        if (categoryMatched) {
          score += 35;
          reasons.add('景點分類符合');
        }

        if (matchedTags.isNotEmpty) {
          score += min(matchedTags.length, 3) * 12;
          reasons.add('符合標籤：${matchedTags.join('、')}');
        }

        if (preferredCounty.isNotEmpty && placeCounty == preferredCounty) {
          score += 15;
          reasons.add('位於${PlaceService.countyFor(place)}');
        }

        if (place.rating > 0) {
          score += place.rating.clamp(0, 5) * 3;
          reasons.add('評分 ${place.rating.toStringAsFixed(1)}');
        }

        if (place.price_level > 0 && request.budget_level > 0) {
          if (place.price_level <= request.budget_level) {
            score += 8;
            reasons.add('符合預算等級');
          } else if (place.price_level > request.budget_level + 1) {
            continue;
          }
        }

        if (originalPlace != null &&
            PlaceService.hasUsableCoordinates(originalPlace)) {
          final distance = _distanceKm(originalPlace, place);

          final approximateLimitKm = replacement.maxTravelMinutes * 0.4;

          if (distance > approximateLimitKm) {
            continue;
          }

          if (distance <= 2) {
            score += 25;
            reasons.add('距離原景點約 2 公里內');
          } else if (distance <= 5) {
            score += 17;
            reasons.add('距離原景點約 5 公里內');
          } else if (distance <= 10) {
            score += 8;
            reasons.add('距離原景點約 10 公里內');
          }
        }

        candidates.add(
          WeatherAlternativeCandidate(
            place: place,
            score: score,
            reasons: reasons,
          ),
        );
      }

      candidates.sort((first, second) {
        final scoreComparison = second.score.compareTo(first.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return second.place.rating.compareTo(first.place.rating);
      });

      results.add(
        WeatherResolvedReplacement(
          strategy: replacement,
          original: WeatherItineraryPlaceSnapshot(
            occurrenceId: originalRequestPlace.occurrenceId,
            placeId: originalRequestPlace.placeId,
            name: originalRequestPlace.name,
          ),
          candidates: candidates.take(candidateLimit).toList(growable: false),
        ),
      );
    }

    return List.unmodifiable(results);
  }

  bool _fitsOpeningHours({
    required Place place,
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
  }) {
    final periods = place.getOpeningPeriodsForDate(date);

    if (periods.isEmpty) {
      return true;
    }

    return periods.any(
      (period) =>
          startMinutes >= period.openMinutes &&
          endMinutes <= period.closeMinutes,
    );
  }

  String _normalize(String value) {
    return value.trim().replaceAll('臺', '台').toLowerCase();
  }

  double _distanceKm(Place first, Place second) {
    const earthRadiusKm = 6371.0;

    final latitude1 = _radians(first.latitude);
    final latitude2 = _radians(second.latitude);

    final latitudeDifference = _radians(second.latitude - first.latitude);

    final longitudeDifference = _radians(second.longitude - first.longitude);

    final value =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(latitude1) *
            cos(latitude2) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);

    return earthRadiusKm * 2 * atan2(sqrt(value), sqrt(1 - value));
  }

  double _radians(double degrees) {
    return degrees * pi / 180;
  }
}
