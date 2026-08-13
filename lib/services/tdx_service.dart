import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/tdx_route.dart';

class TdxService {
  final String clientId = 'clairelee20041020-1df10dd6-36e4-4dd8';
  final String clientSecret = '691da7f7-9311-4f4d-b777-9afb94dbb428';

  String? _accessToken;

  Future<String> fetchAccessToken() async {
    if (_accessToken != null) return _accessToken!;

    final response = await http.post(
      Uri.parse('https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token'),
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  bool _isWalkMode(String mode) {
    final m = mode.toLowerCase();
    return m == 'pedestrian' || m == 'walking' || m == 'walk';
  }

  Future<List<TdxRoute>> getRoutingOptions({
    required String origin,
    required String destination,
  }) async {
    final token = await fetchAccessToken();

    final destParts = destination.split(',');
    final double destLat = destParts.length > 0 ? (double.tryParse(destParts[0]) ?? 0.0) : 0.0;
    final double destLng = destParts.length > 1 ? (double.tryParse(destParts[1]) ?? 0.0) : 0.0;

    final url = Uri.https(
      'tdx.transportdata.tw',
      '/api/maas/routing',
      {
        'origin': origin,
        'destination': destination,
        'top': '10',
        'gc': '0.5',
        'transit': '3,4,5,6,7,8,9',
        'first_mile_mode': '0',   // 0 = 走路，避免 TDX 給腳踏車/叫車選項
        'last_mile_mode': '0',    // 0 = 走路
      },
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('路線查詢失敗: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    List routesJson = json['data']?['routes'] ?? [];

    List<_ScoredRoute> candidates = [];
    Set<String> seenPatterns = {};

    for (var routeItem in routesJson) {
      print('=== routeItem ===\n${jsonEncode(routeItem)}\n=================');
      try {
        List sectionsList = routeItem['sections'] ?? [];
        if (sectionsList.isEmpty) continue;

        bool isInvalid = false;

        // 檢查⓪：這是公共運輸規劃 app，不接受叫車(YOXI)/租車/租借腳踏車等付費私人運具路段
        for (var section in sectionsList) {
            String type = (section['type'] ?? '').toString().toLowerCase();
            String mode = (section['transport']?['mode'] ?? '').toString().toLowerCase();
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
          String lastType = (lastSection['type'] ?? '').toString().toLowerCase();
          bool isLastSectionWalk = _isWalkMode(lastType);

          if (isLastSectionWalk) {
            var arrivalPlace = lastSection['arrival']?['place']?['location'];
            double? lastLat = _toDoubleOrNull(arrivalPlace?['lat']);
            double? lastLng = _toDoubleOrNull(arrivalPlace?['lng']);

            if (lastLat == null || lastLng == null || destLat == 0.0 || destLng == 0.0) {
              isInvalid = true; // 座標解析失敗，不可信，直接剔除
            } else {
              double remainingDistanceKm = _calculateDistance(lastLat, lastLng, destLat, destLng);
              if (remainingDistanceKm > 1.2) {
                isInvalid = true; // 實際座標距離目的地太遠，不可能用這段步行時間走到
              }
            }
          }
        }

        if (isInvalid) continue;

        TdxRoute route = TdxRoute.fromJson(routeItem);

        String pattern = route.sections
            .where((s) => !_isWalkMode(s.mode))
            .map((s) => '${s.lineName ?? s.mode}')
            .join(' -> ');
        if (pattern.isEmpty) pattern = 'WALK_ONLY';
        if (seenPatterns.contains(pattern)) continue;
        seenPatterns.add(pattern);

        final walkSections = route.sections.where((s) => _isWalkMode(s.mode));
        int totalWalkSec = walkSections.fold(0, (sum, s) => sum + s.travelTime);
        int maxWalkSec = walkSections.fold(0, (maxV, s) => s.travelTime > maxV ? s.travelTime : maxV);

        candidates.add(_ScoredRoute(
          route: route,
          totalWalkSec: totalWalkSec,
          maxWalkSec: maxWalkSec,
          transfers: route.transfers,
          isPureWalk: pattern == 'WALK_ONLY',
        ));
      } catch (e) {
        print('單條路線解析失敗跳過: $e');
      }
    }

    if (candidates.isEmpty) return [];

    final stages = [
      _RelaxStage(maxSingleWalkSec: 15 * 60, maxTransfers: 1),
      _RelaxStage(maxSingleWalkSec: 15 * 60, maxTransfers: 3),
      _RelaxStage(maxSingleWalkSec: 25 * 60, maxTransfers: 3),
      _RelaxStage(maxSingleWalkSec: 40 * 60, maxTransfers: 5),
      _RelaxStage(maxSingleWalkSec: 1 << 30, maxTransfers: 1 << 30),
    ];

    List<_ScoredRoute> picked = [];
    final Set<TdxRoute> pickedRoutes = {};

    for (final stage in stages) {
      final stageMatches = candidates.where((c) =>
          !pickedRoutes.contains(c.route) &&
          !c.isPureWalk &&
          c.maxWalkSec <= stage.maxSingleWalkSec &&
          c.transfers <= stage.maxTransfers).toList()
        ..sort((a, b) {
          int walkCompare = a.totalWalkSec.compareTo(b.totalWalkSec);
          if (walkCompare != 0) return walkCompare;
          return a.transfers.compareTo(b.transfers);
        });

      for (final c in stageMatches) {
        if (picked.length >= 10) break;
        picked.add(c);
        pickedRoutes.add(c.route);
      }

      if (picked.length >= 5) break;
    }

    if (picked.isEmpty) {
      final walkOnly = candidates.where((c) => c.isPureWalk).toList()
        ..sort((a, b) => a.totalWalkSec.compareTo(b.totalWalkSec));
      picked.addAll(walkOnly.take(5));
    }

    return picked.take(10).map((c) => c.route).toList();
  }
}

class _ScoredRoute {
  final TdxRoute route;
  final int totalWalkSec;
  final int maxWalkSec;
  final int transfers;
  final bool isPureWalk;

  _ScoredRoute({
    required this.route,
    required this.totalWalkSec,
    required this.maxWalkSec,
    required this.transfers,
    required this.isPureWalk,
  });
}

class _RelaxStage {
  final int maxSingleWalkSec;
  final int maxTransfers;

  _RelaxStage({required this.maxSingleWalkSec, required this.maxTransfers});
}