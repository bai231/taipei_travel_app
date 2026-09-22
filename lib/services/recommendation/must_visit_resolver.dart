import '../../models/must_visit_resolution.dart';
import '../../models/place.dart';
import '../../models/recommendation_criteria.dart';
import 'recommendation_candidate_filter.dart';

class MustVisitResolver {
  const MustVisitResolver();

  MustVisitResolution resolve({
    required Iterable<Place> places,
    required RecommendationCriteria criteria,
  }) {
    final attractions = places
        .where((place) => place.type == PlaceType.attraction)
        .toList();

    final matchedPlaces = <Place>[];
    final conflictingPlaces = <Place>[];
    final unmatchedNames = <String>[];

    for (final requestedName in criteria.mustVisitPlaceNames) {
      final place = _findBestMatch(
        requestedName: requestedName,
        places: attractions,
      );

      if (place == null) {
        unmatchedNames.add(requestedName);
        continue;
      }

      final isEligible = RecommendationCandidateFilter.isEligible(
        place: place,
        criteria: criteria,
      );

      if (isEligible) {
        matchedPlaces.add(place);
      } else {
        conflictingPlaces.add(place);
      }
    }

    return MustVisitResolution(
      matchedPlaces: _removeDuplicates(matchedPlaces),
      conflictingPlaces: _removeDuplicates(conflictingPlaces),
      unmatchedNames: unmatchedNames.toSet().toList(),
    );
  }

  Place? _findBestMatch({
    required String requestedName,
    required List<Place> places,
  }) {
    final normalizedRequestedName = _normalizeName(requestedName);

    if (normalizedRequestedName.isEmpty) {
      return null;
    }

    // 第一優先：名稱完全相同。
    for (final place in places) {
      if (_normalizeName(place.name) == normalizedRequestedName) {
        return place;
      }
    }

    // 第二優先：名稱互相包含。
    final partialMatches = places.where((place) {
      final normalizedPlaceName = _normalizeName(place.name);

      return normalizedPlaceName.contains(normalizedRequestedName) ||
          normalizedRequestedName.contains(normalizedPlaceName);
    }).toList();

    if (partialMatches.isEmpty) {
      return null;
    }

    // 有多個部分符合時，選擇名稱長度最接近者。
    partialMatches.sort((a, b) {
      final aDifference =
          (_normalizeName(a.name).length - normalizedRequestedName.length)
              .abs();

      final bDifference =
          (_normalizeName(b.name).length - normalizedRequestedName.length)
              .abs();

      return aDifference.compareTo(bDifference);
    });

    return partialMatches.first;
  }

  List<Place> _removeDuplicates(Iterable<Place> places) {
    final result = <Place>[];
    final seenIds = <String>{};

    for (final place in places) {
      if (seenIds.add(place.id)) {
        result.add(place);
      }
    }

    return result;
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .replaceAll('臺', '台')
        .replaceAll(RegExp(r'[\s　\-－_（）()]'), '')
        .toLowerCase();
  }
}
