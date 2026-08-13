import 'data/fake_places.dart';
import 'models/trip_request.dart';
import 'services/recommandation_service.dart';
import 'services/trip_generator_service.dart';

void main() {
  final request = TripRequest(
    title: '台北兩日遊',
    startDate: DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 21),
    location: '台北',
    people: 4,
    budget: 8000,
    preferences: ['攝影', '美食', '夜景'],
  );

  // 1. 取得推薦景點
  final recommendService = RecommendService();

  final recommendedPlaces = recommendService.recommend(fakePlaces, request);

  // 2. 生成行程
  final generator = TripGeneratorService();

  final trip = generator.generate(recommendedPlaces, request.days);

  // 3. 印出行程
  print('====================');
  print('      生成行程');
  print('====================');

  for (int day = 1; day <= request.days; day++) {
    print('');
    print('Day $day');
    print('--------------------');

    final items = trip.getItemsForDay(day);

    for (final item in items) {
      print(
        '${_formatTime(item.startMinutes)} '
        '- '
        '${_formatTime(item.endMinutes)} '
        '${item.place.name}',
      );
    }
  }
}

String _formatTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;

  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
