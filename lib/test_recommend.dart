import 'data/fake_places.dart';
import 'models/trip_request.dart';
import 'services/recommandation_service.dart';

void main() {
  // 建立一個假的使用者需求
  final request = TripRequest(
    title: '台北兩日遊',
    startDate: DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 21),
    location: '台北',
    people: 5,
    budget: 8000,
    preferences: ['購物'],
    aiPrompt: '',
  );

  // 建立推薦服務
  final service = RecommendService();

  // 取得推薦結果
  final result = service.recommend(fakePlaces, request);

  // 印出結果
  print('===== 推薦結果 =====');

  for (final recommended in result) {
    print(
      '${recommended.place.name} '
      '| score: ${recommended.score.toStringAsFixed(2)}',
    );
  }
}
