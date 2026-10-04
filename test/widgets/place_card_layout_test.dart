import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taipei_travel_app/models/place.dart';
import 'package:taipei_travel_app/widgets/place_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-public-key',
    );
  });

  testWidgets('窄螢幕放大字體時，長分類與距離不擠出景點卡片', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const place = Place(
      id: '1',
      name: '一個很長的景點名稱',
      category: '文化藝術展演及歷史建築景點',
      description: '',
      address: '',
      latitude: 25.04,
      longitude: 121.52,
      image: '',
      distanceInMeters: 123456789,
      stayTime: 60,
      rating: 4.5,
      tags: [],
      price_level: 0,
      openMinutes: 0,
      closeMinutes: 1440,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 170,
              height: 210,
              child: PlaceCard(place: place),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
