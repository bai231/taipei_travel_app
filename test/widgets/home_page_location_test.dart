import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/pages/home_page.dart';
import 'package:taipei_travel_app/services/location_service.dart';

class _LocationAfterRetry implements CurrentLocationGateway {
  int calls = 0;

  @override
  Future<LocationPoint?> getCurrentLocation() async {
    calls++;
    return calls == 1
        ? null
        : const LocationPoint(latitude: 25.04, longitude: 121.52);
  }
}

void main() {
  testWidgets('手機未取得定位時說明一般推薦，重試後切換為附近推薦', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final location = _LocationAfterRetry();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: HomePage(placeLoader: () async => [], locationGateway: location),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('景點推薦'), findsOneWidget);
    expect(find.textContaining('目前顯示一般推薦'), findsOneWidget);
    expect(find.text('定位設定'), findsOneWidget);
    expect(find.text('重試定位'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('重試定位'));
    await tester.pumpAndSettle();

    expect(location.calls, 2);
    expect(find.text('附近景點推薦'), findsOneWidget);
    expect(find.textContaining('目前顯示一般推薦'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
