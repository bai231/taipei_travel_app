import 'dart:convert';

import 'package:http/http.dart' as http;

import 'transit_realtime_monitor.dart';

/// Foreground-only TDX realtime client for the next bus or TRA section.
/// Credentials are supplied through --dart-define-from-file and are never
/// persisted by this service.
class TdxRealtimeService implements TransitRealtimeGateway {
  static const _tokenUri =
      'https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token';
  static const _apiHost = 'tdx.transportdata.tw';
  static const _clientId = String.fromEnvironment('TDX_CLIENT_ID');
  static const _clientSecret = String.fromEnvironment('TDX_CLIENT_SECRET');

  final http.Client _client;
  final String clientId;
  final String clientSecret;
  final Duration minimumRequestInterval;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  String? _accessToken;
  DateTime? _tokenExpiresAt;
  DateTime? _lastRequestAt;
  List<_TraStation>? _traStations;
  DateTime? _traAlertsLoadedAt;
  List<Map<String, dynamic>> _traAlerts = const [];

  TdxRealtimeService({
    http.Client? client,
    String? clientId,
    String? clientSecret,
    this.minimumRequestInterval = const Duration(seconds: 2),
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _client = client ?? http.Client(),
       clientId = clientId ?? _clientId,
       clientSecret = clientSecret ?? _clientSecret,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;

  @override
  Future<TransitRealtimeObservation?> load(
    TransitSectionIdentity identity,
  ) async {
    if (!isConfigured) return null;
    return switch (identity.provider) {
      TransitProvider.bus => _loadBus(identity),
      TransitProvider.tra => _loadTra(identity),
    };
  }

  Future<TransitRealtimeObservation?> _loadBus(
    TransitSectionIdentity identity,
  ) async {
    final section = identity.section;
    final routeName = section.routeId ?? section.lineName;
    final stopName = section.departureTitle;
    if (routeName == null || stopName == null) return null;

    final operator = (section.operatorCode ?? '').toLowerCase();
    final city = section.city?.trim();
    final isInterCity =
        operator.contains('highway') || city == null || city.isEmpty;
    final path = isInterCity
        ? '/api/basic/v2/Bus/EstimatedTimeOfArrival/InterCity/'
              '$routeName'
        : '/api/basic/v2/Bus/EstimatedTimeOfArrival/City/'
              '$city/$routeName';
    final decoded = await _get(Uri.https(_apiHost, path, {r'$format': 'JSON'}));
    if (decoded is! List) return null;

    final candidates = decoded.whereType<Map>().where((item) {
      final name = _localizedName(item['StopName']);
      final uid = _text(item['StopUID']);
      return _sameStop(name, stopName) ||
          (section.departureStopId != null && uid == section.departureStopId);
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final first = _integer(a['EstimateTime']) ?? 1 << 30;
      final second = _integer(b['EstimateTime']) ?? 1 << 30;
      return first.compareTo(second);
    });
    final item = candidates.first;
    final estimateSeconds = _integer(item['EstimateTime']);
    final stopStatus = _integer(item['StopStatus']) ?? 0;
    final updatedAt =
        DateTime.tryParse(_text(item['SrcUpdateTime']) ?? '') ??
        DateTime.tryParse(_text(item['UpdateTime']) ?? '') ??
        _now();
    final expectedDeparture = estimateSeconds == null
        ? identity.scheduledDeparture
        : updatedAt.add(Duration(seconds: estimateSeconds));
    return TransitRealtimeObservation(
      expectedDeparture: expectedDeparture,
      expectedArrival: identity.scheduledArrival,
      updatedAt: updatedAt,
      cancelled: stopStatus == 4,
      disrupted: stopStatus == 2 || stopStatus == 3,
      message: switch (stopStatus) {
        2 => '公車目前交管不停靠此站。',
        3 => '末班公車已駛離。',
        4 => '今日未營運。',
        _ => null,
      },
      source: 'TDX Bus ETA',
    );
  }

  Future<TransitRealtimeObservation?> _loadTra(
    TransitSectionIdentity identity,
  ) async {
    final section = identity.section;
    final originId =
        section.departureStopId ?? await _traStationId(section.departureTitle);
    final destinationId =
        section.arrivalStopId ?? await _traStationId(section.arrivalTitle);
    if (originId == null || destinationId == null) return null;

    final trainNo = await _resolveTraTrainNo(
      identity,
      originId: originId,
      destinationId: destinationId,
    );
    if (trainNo == null) return null;
    final decoded = await _get(
      Uri.https(_apiHost, '/api/basic/v3/Rail/TRA/TrainLiveBoard', {
        r'$filter': "TrainNo eq '$trainNo'",
        r'$format': 'JSON',
      }),
    );
    final boards = decoded is Map ? decoded['TrainLiveBoards'] : null;
    if (boards is! List || boards.isEmpty || boards.first is! Map) return null;
    final board = Map<String, dynamic>.from(boards.first as Map);
    final delayMinutes = _integer(board['DelayTime']) ?? 0;
    String? alertMessage;
    try {
      alertMessage = await _matchingTraAlert(identity, trainNo);
    } on TdxRealtimeException {
      // 即時通阻暫時不可用時，仍保留車次誤點判斷。
    }
    final runningStatus = _integer(
      board['RunningStatus'] ?? board['TrainStatus'] ?? board['Status'],
    );
    final cancelled = board['IsCancelled'] == true || runningStatus == -2;
    final updatedAt =
        DateTime.tryParse(_text(decoded['SrcUpdateTime']) ?? '') ??
        DateTime.tryParse(_text(decoded['UpdateTime']) ?? '') ??
        _now();
    final scheduledDeparture = identity.scheduledDeparture;
    final scheduledArrival = identity.scheduledArrival;
    return TransitRealtimeObservation(
      expectedDeparture: scheduledDeparture?.add(
        Duration(minutes: delayMinutes),
      ),
      expectedArrival: scheduledArrival?.add(Duration(minutes: delayMinutes)),
      updatedAt: updatedAt,
      cancelled: cancelled,
      disrupted: alertMessage != null,
      message: cancelled
          ? '臺鐵 $trainNo 次已取消。'
          : alertMessage ??
                (delayMinutes > 0
                    ? '臺鐵 $trainNo 次目前約誤點 $delayMinutes 分鐘。'
                    : null),
      source: 'TDX TRA TrainLiveBoard',
    );
  }

  Future<String?> _matchingTraAlert(
    TransitSectionIdentity identity,
    String trainNo,
  ) async {
    final now = _now();
    if (_traAlertsLoadedAt == null ||
        now.difference(_traAlertsLoadedAt!) > const Duration(minutes: 1)) {
      final decoded = await _get(
        Uri.https(_apiHost, '/api/basic/v3/Rail/TRA/Alert', {
          r'$format': 'JSON',
        }),
      );
      final alerts = decoded is Map ? decoded['Alerts'] : null;
      _traAlerts = alerts is List
          ? alerts
                .whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .toList(growable: false)
          : const [];
      _traAlertsLoadedAt = now;
    }
    final origin = identity.section.departureTitle;
    final destination = identity.section.arrivalTitle;
    for (final alert in _traAlerts) {
      final searchable = jsonEncode(alert).toLowerCase();
      final trainMatched = _containsToken(searchable, trainNo);
      final stationsMatched =
          origin != null &&
          destination != null &&
          searchable.contains(origin.toLowerCase()) &&
          searchable.contains(destination.toLowerCase());
      if (!trainMatched && !stationsMatched) continue;
      return _alertText(alert) ?? '臺鐵公告此路段目前有營運異常。';
    }
    return null;
  }

  Future<String?> _resolveTraTrainNo(
    TransitSectionIdentity identity, {
    required String originId,
    required String destinationId,
  }) async {
    final direct = identity.section.routeId;
    if (direct != null && RegExp(r'^\d+[A-Za-z]?$').hasMatch(direct)) {
      return direct;
    }
    final date = identity.serviceDate;
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final decoded = await _get(
      Uri.https(
        _apiHost,
        '/api/basic/v3/Rail/TRA/DailyTrainTimetable/OD/'
        '$originId/to/$destinationId/$dateText',
        {r'$format': 'JSON'},
      ),
    );
    final timetables = decoded is Map ? decoded['TrainTimetables'] : null;
    if (timetables is! List) return null;
    final planned = identity.scheduledDeparture;
    Map? best;
    var bestDifference = const Duration(days: 365);
    for (final raw in timetables.whereType<Map>()) {
      final stopTimes = raw['StopTimes'];
      if (stopTimes is! List || stopTimes.isEmpty) continue;
      final originStop = stopTimes.whereType<Map>().firstWhere(
        (stop) => _text(stop['StationID']) == originId,
        orElse: () => const {},
      );
      final departureText = _text(originStop['DepartureTime']);
      final departure = _timeOnDate(date, departureText);
      if (departure == null || planned == null) continue;
      final difference = departure.difference(planned).abs();
      if (difference < bestDifference) {
        best = raw;
        bestDifference = difference;
      }
    }
    if (best == null || bestDifference > const Duration(minutes: 5)) {
      return null;
    }
    final info = best['DailyTrainInfo'];
    return info is Map ? _text(info['TrainNo']) : null;
  }

  Future<String?> _traStationId(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    _traStations ??= await _loadTraStations();
    final normalized = _normalizeStop(name);
    for (final station in _traStations!) {
      if (_normalizeStop(station.name) == normalized) return station.id;
    }
    return null;
  }

  Future<List<_TraStation>> _loadTraStations() async {
    final decoded = await _get(
      Uri.https(_apiHost, '/api/basic/v3/Rail/TRA/Station', {
        r'$format': 'JSON',
      }),
    );
    final stations = decoded is Map ? decoded['Stations'] : null;
    if (stations is! List) return const [];
    return stations
        .whereType<Map>()
        .map((item) {
          final name = _localizedName(item['StationName']) ?? '';
          return _TraStation(_text(item['StationID']) ?? '', name);
        })
        .where((station) => station.id.isNotEmpty && station.name.isNotEmpty)
        .toList();
  }

  Future<dynamic> _get(Uri uri) async {
    final token = await _token();
    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt != null) {
      final remaining =
          minimumRequestInterval - _now().difference(lastRequestAt);
      if (remaining > Duration.zero) await _delay(remaining);
    }
    _lastRequestAt = _now();
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 429) {
      throw const TdxRealtimeRateLimitException();
    }
    if (response.statusCode != 200) {
      throw TdxRealtimeException(response.statusCode);
    }
    return jsonDecode(response.body);
  }

  Future<String> _token() async {
    final now = _now();
    if (_accessToken != null &&
        _tokenExpiresAt != null &&
        now.isBefore(_tokenExpiresAt!)) {
      return _accessToken!;
    }
    final response = await _client.post(
      Uri.parse(_tokenUri),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );
    if (response.statusCode != 200) {
      throw TdxRealtimeException(response.statusCode);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = _text(decoded['access_token']);
    if (_accessToken == null) throw const TdxRealtimeException(200);
    final expiresIn = _integer(decoded['expires_in']) ?? 300;
    _tokenExpiresAt = now.add(Duration(seconds: expiresIn - 30));
    return _accessToken!;
  }

  void dispose() => _client.close();
}

class TdxRealtimeException implements Exception {
  final int statusCode;
  const TdxRealtimeException(this.statusCode);
}

class TdxRealtimeRateLimitException extends TdxRealtimeException {
  const TdxRealtimeRateLimitException() : super(429);
}

class _TraStation {
  final String id;
  final String name;
  const _TraStation(this.id, this.name);
}

String? _localizedName(Object? value) {
  if (value is String) return value;
  if (value is Map) {
    return _text(value['Zh_tw'] ?? value['zh_tw'] ?? value['En']);
  }
  return null;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

bool _sameStop(String? first, String second) =>
    first != null && _normalizeStop(first) == _normalizeStop(second);

String _normalizeStop(String value) => value
    .replaceAll('臺', '台')
    .replaceAll(RegExp(r'\s'), '')
    .replaceFirst(RegExp(r'(轉運中心|車站|站)$'), '')
    .toLowerCase();

DateTime? _timeOnDate(DateTime date, String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

bool _containsToken(String value, String token) => RegExp(
  '(^|[^0-9a-z])${RegExp.escape(token.toLowerCase())}'
  r'([^0-9a-z]|$)',
).hasMatch(value);

String? _alertText(Map<String, dynamic> alert) {
  for (final key in const [
    'Description',
    'DescriptionText',
    'Title',
    'Message',
  ]) {
    final localized = _localizedName(alert[key]);
    if (localized != null) return localized;
  }
  return null;
}
