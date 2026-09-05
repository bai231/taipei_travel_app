import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/tdx_route.dart';
import 'tdx_route_ranker.dart';

abstract interface class TdxRoutingGateway {
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  });
}

class TdxRateLimitException implements Exception {
  final Duration retryAfter;

  const TdxRateLimitException({this.retryAfter = const Duration(minutes: 1)});

  @override
  String toString() => 'TDX 請求過於頻繁，請稍後再試。';
}

class TdxService implements TdxRoutingGateway {
  static const int maximumRoutingOptions = 10;
  static const String walkingMileMode = '0';
  static const String maximumWalkingMileMinutes = '40';

  static const String clientId = String.fromEnvironment('TDX_CLIENT_ID');
  static const String clientSecret = String.fromEnvironment(
    'TDX_CLIENT_SECRET',
  );
  final Duration minimumRequestInterval;
  final TdxRouteRanker routeRanker;

  String? _accessToken;
  static Future<void> _globalRoutingQueue = Future<void>.value();
  static DateTime? _globalLastRoutingRequestAt;

  TdxService({
    this.minimumRequestInterval = const Duration(seconds: 2),
    this.routeRanker = const TdxRouteRanker(),
  });

  Future<String> fetchAccessToken() async {
    if (_accessToken != null) return _accessToken!;

    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw StateError(
        '找不到 TDX API 金鑰，請使用 '
        '--dart-define-from-file=config/secrets.json 啟動程式。',
      );
    }

    final response = await http.post(
      Uri.parse(
        'https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      return _accessToken!;
    } else {
      throw Exception('Token 取得失敗: ${response.statusCode}');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  bool _isWalkMode(String mode) {
    final m = mode.toLowerCase();
    return m == 'pedestrian' || m == 'walking' || m == 'walk';
  }

  @override
  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
    DateTime? departureTime,
  }) async {
    final token = await fetchAccessToken();

    final destParts = destination.split(',');
    final double destLat = destParts.isNotEmpty
        ? (double.tryParse(destParts[0]) ?? 0.0)
        : 0.0;
    final double destLng = destParts.length > 1
        ? (double.tryParse(destParts[1]) ?? 0.0)
        : 0.0;

    final queryParameters = <String, String>{
      'origin': origin,
      'destination': destination,
      'top': '$maximumRoutingOptions',
      'gc': '0.5',
      'transit': '3,4,5,6,7,8,9',
      'first_mile_mode': walkingMileMode,
      'first_mile_time': maximumWalkingMileMinutes,
      'last_mile_mode': walkingMileMode,
      'last_mile_time': maximumWalkingMileMinutes,
    };
    if (departureTime != null) {
      queryParameters['depart'] = _formatDepartureTime(departureTime);
    }

    final url = Uri.https(
      'tdx.transportdata.tw',
      '/api/maas/routing',
      queryParameters,
    );

    final response = await _enqueueRoutingRequest(
      () => http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 429) {
      final retryAfterSeconds =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
      throw TdxRateLimitException(
        retryAfter: Duration(seconds: max(1, retryAfterSeconds)),
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        '路線查詢失敗: ${response.statusCode}${_tdxErrorMessage(response)}',
      );
    }

    final json = jsonDecode(response.body);
    List routesJson = json['data']?['routes'] ?? [];

    final candidates = <TdxRoute>[];

    for (var routeItem in routesJson) {
      try {
        List sectionsList = routeItem['sections'] ?? [];
        if (sectionsList.isEmpty) continue;

        bool isInvalid = false;

        // 檢查⓪：這是公共運輸規劃 app，不接受叫車(YOXI)/租車/租借腳踏車等付費私人運具路段
        for (var section in sectionsList) {
          String type = (section['type'] ?? '').toString().toLowerCase();
          String mode = (section['transport']?['mode'] ?? '')
              .toString()
              .toLowerCase();
          if (type == 'drive' || mode == 'yoxi' || type == 'cycle') {
            isInvalid = true;
            break;
          }
        }

        // 檢查①：每一段步行自己回報的速度是否合理（抓 TDX 明顯亂給的 duration/length）
        for (var section in sectionsList) {
          String type = (section['type'] ?? '').toString().toLowerCase();
          if (!_isWalkMode(type)) continue;

          double lengthM = _toDouble(section['travelSummary']?['length']);
          int durationS = (section['travelSummary']?['duration'] ?? 0) as int;
          if (durationS > 0 && lengthM > 0) {
            double speedMPerMin = lengthM / (durationS / 60);
            if (speedMPerMin > 150) {
              isInvalid = true;
              break;
            }
          }
        }

        // 檢查②：關鍵！不要相信 API 自己回報的 length，
        // 直接拿「最後一段步行的到達座標」跟「真正輸入的目的地座標」算實際距離。
        // 這樣即使 TDX 的 length/duration 內部自洽但跟現實不符，也抓得出來。
        if (!isInvalid) {
          var lastSection = sectionsList.last;
          String lastType = (lastSection['type'] ?? '')
              .toString()
              .toLowerCase();
          bool isLastSectionWalk = _isWalkMode(lastType);

          if (isLastSectionWalk) {
            var arrivalPlace = lastSection['arrival']?['place']?['location'];
            double? lastLat = _toDoubleOrNull(arrivalPlace?['lat']);
            double? lastLng = _toDoubleOrNull(arrivalPlace?['lng']);

            if (lastLat == null ||
                lastLng == null ||
                destLat == 0.0 ||
                destLng == 0.0) {
              isInvalid = true; // 座標解析失敗，不可信，直接剔除
            } else {
              double remainingDistanceKm = _calculateDistance(
                lastLat,
                lastLng,
                destLat,
                destLng,
              );
              if (remainingDistanceKm > 1.2) {
                isInvalid = true; // 實際座標距離目的地太遠，不可能用這段步行時間走到
              }
            }
          }
        }

        if (isInvalid) continue;

        TdxRoute route = TdxRoute.fromJson(routeItem);

        candidates.add(route);
      } catch (_) {}
    }

    if (candidates.isEmpty) return [];
    return routeRanker.rank(candidates, limit: maximumRoutingOptions);
  }

  String _formatDepartureTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${twoDigits(value.month)}-${twoDigits(value.day)}T'
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
        '${twoDigits(value.second)}';
  }

  Future<void> _waitForRoutingRequestSlot() async {
    final lastRequestAt = _globalLastRoutingRequestAt;
    if (lastRequestAt == null || minimumRequestInterval <= Duration.zero) {
      return;
    }
    final remaining =
        minimumRequestInterval - DateTime.now().difference(lastRequestAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<T> _enqueueRoutingRequest<T>(Future<T> Function() request) async {
    final previousRequest = _globalRoutingQueue;
    final releaseQueue = Completer<void>();
    _globalRoutingQueue = releaseQueue.future;

    await previousRequest;
    try {
      await _waitForRoutingRequestSlot();
      return await request();
    } finally {
      _globalLastRoutingRequestAt = DateTime.now();
      releaseQueue.complete();
    }
  }

  String _tdxErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['msg']?.toString().trim() ?? '';
        if (message.isNotEmpty) return ' ($message)';
      }
    } catch (_) {}
    return '';
  }
}
