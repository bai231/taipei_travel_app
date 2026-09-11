import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/models/planner_favorites.dart';
import 'package:taipei_travel_app/widgets/trip/planner_item_picker.dart';

void main() {
  testWidgets('收藏以資料夾取代縣市，資料夾切換保留搜尋與原縣市', (tester) async {
    final a = _place('收藏甲');
    final b = _place('收藏乙');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlannerItemPicker(
            type: PlaceType.attraction,
            places: [a, b],
            selectedPlaceIds: const {},
            favoritePlaceIds: {a.id, b.id},
            favoriteFolders: [
              PlannerFavoriteFolder(id: 'a', title: '甲資料夾', placeIds: {a.id}),
              PlannerFavoriteFolder(id: 'b', title: '乙資料夾', placeIds: {b.id}),
              PlannerFavoriteFolder(id: 'empty', title: '空資料夾', placeIds: {}),
            ],
            onConfirmed: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('縣市'), findsOneWidget);
    await tester.tap(find.text('我的收藏'));
    await tester.pumpAndSettle();
    expect(find.text('縣市'), findsNothing);
    expect(find.text('收藏資料夾'), findsOneWidget);
    await tester.tap(find.text('全部收藏').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('甲資料夾').last);
    await tester.pumpAndSettle();
    expect(find.text('收藏甲'), findsOneWidget);
    expect(find.text('收藏乙'), findsNothing);
    await tester.tap(find.text('甲資料夾').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('乙資料夾').last);
    await tester.pumpAndSettle();
    expect(find.text('收藏甲'), findsNothing);
    expect(find.text('收藏乙'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '甲');
    await tester.pump();
    expect(find.text('收藏乙'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    expect(find.text('縣市'), findsOneWidget);
    expect(find.text('收藏資料夾'), findsNothing);
    expect(find.text('收藏甲'), findsOneWidget);
    expect(find.text('收藏乙'), findsOneWidget);
  });

  for (final type in PlaceType.values) {
    testWidgets('$type 評分排序保留收藏搜尋與勾選，確認維持目錄順序', (tester) async {
      final a = _place('候選甲', type: type);
      final b = _place('候選乙', type: type);
      final c = _place('其他', type: type);
      List<Place>? confirmed;
      Widget app(Map<String, num> scores) => MaterialApp(
        home: Scaffold(
          body: PlannerItemPicker(
            type: type,
            places: [a, b, c],
            candidateScoresByPlaceId: scores,
            favoritePlaceIds: {a.id, b.id},
            selectedPlaceIds: {a.id, b.id},
            onConfirmed: (value) => confirmed = value,
          ),
        ),
      );
      List<String> titles() => tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((tile) => (tile.title! as Text).data!)
          .toList();
      await tester.pumpWidget(app({a.id: 1, b.id: 2, c.id: 3}));
      expect(titles(), ['其他', '候選乙', '候選甲']);
      if (type == PlaceType.attraction) {
        await tester.tap(find.text('我的收藏'));
        await tester.pump();
        expect(titles(), ['候選乙', '候選甲']);
      } else {
        expect(find.text('我的收藏'), findsNothing);
      }
      await tester.enterText(find.byType(TextField), '甲');
      await tester.pump();
      expect(titles(), ['候選甲']);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpWidget(app({a.id: 4, b.id: 2}));
      expect(
        titles(),
        type == PlaceType.attraction ? ['候選甲', '候選乙'] : ['候選甲', '候選乙', '其他'],
      );
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .where((tile) => (tile.title! as Text).data != '其他')
            .every((tile) => tile.value == true),
        isTrue,
      );
      await tester.pumpWidget(app({a.id: 1, b.id: 2}));
      await tester.tap(find.text('套用選擇'));
      await tester.pump();
      expect(confirmed, [a, b]);
    });
  }

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
