import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/services/planner_candidate_ranking.dart';

void main() {
  final places = [
    for (final id in ['a', 'b', 'c', 'd', 'e', 'f'])
      Place.fromJson({'id': id, 'name': id}),
  ];

  test(
    'descending scores, stable ties, invalid scores last; input unchanged',
    () {
      final scores = <String, num>{
        places[0].id: -1,
        places[1].id: 5,
        places[2].id: 5,
        places[3].id: double.nan,
        places[4].id: double.infinity,
        'unknown': 999,
      };
      final original = List<Place>.of(places);
      final result = rankPlannerCandidates(places, scoresByPlaceId: scores);
      expect(result, [places[1], places[2], places[0], ...places.skip(3)]);
      expect(places, original);
      expect(scores.length, 6);
    },
  );

  test('empty scores preserve order and return a separate list', () {
    final result = rankPlannerCandidates(places);
    expect(result, places);
    expect(identical(result, places), isFalse);
    expect(rankPlannerCandidates([]), isEmpty);
  });

  test('zero is scored and negative infinity is unscored', () {
    expect(
      rankPlannerCandidates(
        places.take(2).toList(),
        scoresByPlaceId: {
          places[0].id: double.negativeInfinity,
          places[1].id: 0,
        },
      ),
      [places[1], places[0]],
    );
  });
}
