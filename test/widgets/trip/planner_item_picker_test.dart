import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/widgets/trip/planner_item_picker.dart';

void main() {
  testWidgets('無座標住宿可依縣市顯示，但不能勾選進入路線', (tester) async {
    final accommodations = [
      for (final county in ['臺中市', '高雄市'])
        Place.fromJson({
          '唯一識別碼': county,
          '資料名稱': '$county測試住宿',
          '資料類型': 'Hotel',
          '縣市名稱': county,
        }),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlannerItemPicker(
            type: PlaceType.accommodation,
            places: accommodations,
            selectedPlaceIds: const {},
            onConfirmed: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('臺中市測試住宿'), findsOneWidget);
    expect(find.text('高雄市測試住宿'), findsOneWidget);
    await tester.tap(find.text('全部縣市').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('台中市').last);
    await tester.pumpAndSettle();

    expect(find.text('臺中市測試住宿'), findsOneWidget);
    expect(find.text('高雄市測試住宿'), findsNothing);
    expect(find.textContaining('缺少座標，暫不可排入行程'), findsOneWidget);
    final tile = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tile.onChanged, isNull);
    expect(tile.value, isFalse);
    expect(find.text('已選 0 個住宿'), findsOneWidget);
  });

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
    //priceLevel: 0,
    estimatedCost: 0,
    openMinutes: 0,
    closeMinutes: 1440,
  );
}
