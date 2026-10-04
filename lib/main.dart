import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/route_planning/pages/itinerary_result_page.dart';
import 'features/route_planning/services/active_guardian_session.dart';
import 'routes/app_routes.dart';
import 'services/trip_notification_service.dart';
import 'theme/app_theme.dart';
import 'models/place.dart';
import 'services/language_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

SupabaseClient get supabase => Supabase.instance.client;
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hvncnzimkefaqsngtykd.supabase.co',
    anonKey: 'sb_publishable_gS2PlPMA2sUxe7eOu3DXZA_-jaYiwPN',
  );

  TripNotificationService.onNotificationTap = (payload) {
    if (payload == null || !payload.startsWith('guardian:')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ActiveGuardianSession.active;
      final navigator = appNavigatorKey.currentState;
      if (session == null || navigator == null) return;
      if (payload.startsWith('guardian:weather:') &&
          payload != 'guardian:weather:${session.id}') {
        return;
      }
      if (session.hasAttachedPage) {
        session.onForeground?.call();
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ItineraryResultPage(
            itinerary: session.itinerary,
            dependencies: session.dependencies,
          ),
        ),
      );
    });
  };

  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService().currentLocale,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          builder: (context, child) =>
              ValueListenableBuilder<ActiveGuardianSession?>(
                valueListenable: ActiveGuardianSession.activeListenable,
                builder: (context, session, _) => Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (session != null && !session.hasAttachedPage)
                      Positioned(
                        right: 16,
                        bottom: 20,
                        child: SafeArea(
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(24),
                            child: TextButton.icon(
                              onPressed: () {
                                appNavigatorKey.currentState?.push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ItineraryResultPage(
                                      itinerary: session.itinerary,
                                      dependencies: session.dependencies,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.navigation_outlined),
                              label: const Text('返回守護行程'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          debugShowCheckedModeBanner: false,
          title: 'Travel App',
          locale: currentLocale,
          supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          initialRoute: AppRoutes.home,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
