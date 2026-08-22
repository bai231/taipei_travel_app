import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/widgets/trip/planner_item_picker.dart';

void main() {
  testWidgets('Picker 只顯示目前類型並可加入項目', (tester) async {
    Place? selectedPlace;
    final restaurant = _place(
      '台北餐廳',
      type: PlaceType.restaurant,
      category: '餐廳',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlannerItemPicker(
            type: PlaceType.restaurant,
            places: [_place('台北景點'), restaurant],
            selectedPlaceIds: const {},
            onConfirmed: (places) => selectedPlace = places.single,
          ),
        ),
      ),
    );

    expect(find.text('選擇餐廳'), findsOneWidget);
    expect(find.text('台北餐廳'), findsOneWidget);
    expect(find.text('台北景點'), findsNothing);

    await tester.tap(find.text('台北餐廳'));
    await tester.pump();

    expect(find.text('已選 1 個餐廳'), findsOneWidget);

    await tester.tap(find.text('套用選擇'));
    await tester.pump();

    expect(selectedPlace, restaurant);
  });
}

Place _place(
  String name, {
  PlaceType type = PlaceType.attraction,
  String category = '景點',
}) {
  return Place(
    id: name,
    name: name,
    category: category,
    description: '',
    address: '台北市中正區',
    latitude: 25.04,
    longitude: 121.51,
    image: '',
    type: type,
    stayTime: 60,
    rating: 4,
    tags: const [],
    priceLevel: 0,
    estimatedCost: 0,
    openMinutes: 0,
    closeMinutes: 1440,
  );
}
