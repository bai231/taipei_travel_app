import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taipei_travel_app/services/planner_favorites_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fail in [false, true]) {
    test(
      'cloud adapter filters owner, maps IDs, propagates errors: $fail',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            final table = request.url.pathSegments.last;
            if (table == 'token') {
              String encode(Object value) => base64Url
                  .encode(utf8.encode(jsonEncode(value)))
                  .replaceAll('=', '');
              final token =
                  '${encode({'alg': 'HS256'})}.${encode({'sub': 'user-a', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.test';
              return http.Response(
                jsonEncode({
                  'access_token': token,
                  'refresh_token': 'test-refresh',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'user': {
                    'id': 'user-a',
                    'aud': 'authenticated',
                    'app_metadata': {},
                    'user_metadata': {},
                    'created_at': '2026-01-01T00:00:00Z',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            requests.add(request);
            if (fail) {
              return http.Response(
                '{"message":"denied","code":"42501"}',
                403,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            final rows = switch (table) {
              'favorites' => [
                {'place_id': 42},
              ],
              'folders' => [
                {'id': 7, 'title': '我的資料夾'},
              ],
              'folder_places' => [
                {'place_id': 42},
              ],
              _ => throw StateError('Unexpected request'),
            };
            return http.Response(
              jsonEncode(rows),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await expectLater(
          PlannerFavoritesService(client).load(),
          throwsStateError,
        );
        expect(requests, isEmpty);
        await client.auth.signInWithPassword(
          email: 'test@example.com',
          password: 'test',
        );
        if (fail) {
          await expectLater(
            PlannerFavoritesService(client).load(),
            throwsA(isA<PostgrestException>()),
          );
        } else {
          final result = await PlannerFavoritesService(client).load();
          expect(result.placeIds, {'42'});
          expect(result.folders.single.id, '7');
          expect(result.folders.single.placeIds, {'42'});
          expect(requests[0].url.queryParameters['user_id'], 'eq.user-a');
          expect(requests[1].url.queryParameters['user_id'], 'eq.user-a');
          expect(requests[2].url.queryParameters['folder_id'], 'eq.7');
          expect(requests.every((r) => r.method == 'GET'), isTrue);
        }
      },
    );
  }
}
