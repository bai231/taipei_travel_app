import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'src/tdx_place_matcher.dart';

const _tdxTokenUrl =
    'https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token';
const _tdxTourismBaseUrl =
    'https://tdx.transportdata.tw/api/tourism/service/odata/V2/Tourism';

Future<void> main(List<String> arguments) async {
  final options = _DryRunOptions.parse(arguments);
  final environment = Platform.environment;
  final supabaseUrl = _requiredEnvironment(environment, 'SUPABASE_URL');
  final supabaseAnonKey = _requiredEnvironment(
    environment,
    'SUPABASE_ANON_KEY',
  );
  final tdxClientId = _requiredEnvironment(environment, 'TDX_CLIENT_ID');
  final tdxClientSecret = _requiredEnvironment(
    environment,
    'TDX_CLIENT_SECRET',
  );

  final client = http.Client();
  try {
    stdout.writeln('讀取 Supabase 景點資料...');
    var localPlaces = await _fetchSupabasePlaces(
      client,
      supabaseUrl: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    if (options.limit != null && localPlaces.length > options.limit!) {
      localPlaces = localPlaces.take(options.limit!).toList();
    }
    final placesNeedingData = localPlaces
        .where((place) => place.needsData)
        .toList();
    stdout.writeln(
      'Supabase 共 ${localPlaces.length} 筆，需補資料 ${placesNeedingData.length} 筆。',
    );

    stdout.writeln('取得 TDX Access Token...');
    final accessToken = await _fetchTdxAccessToken(
      client,
      clientId: tdxClientId,
      clientSecret: tdxClientSecret,
    );

    stdout.writeln('下載 TDX 景點基本資料...');
    final attractionJson = await _fetchTdxCollection(
      client,
      accessToken: accessToken,
      path: 'Attraction',
      select: [
        'AttractionID',
        'AttractionName',
        'AlternateNames',
        'PositionLat',
        'PositionLon',
        'AttractionClasses',
        'PostalAddress',
        'ServiceTimeInfo',
        'VisitDuration',
      ],
    );

    stdout.writeln('下載 TDX 景點營運時間資料...');
    final serviceTimeJson = await _fetchTdxCollection(
      client,
      accessToken: accessToken,
      path: 'Attraction/ServiceTime',
      select: ['AttractionID', 'AttractionName', 'ServiceTimes'],
    );

    final periodsByAttractionId = <String, List<TdxServicePeriod>>{};
    for (final item in serviceTimeJson) {
      final attractionId = item['AttractionID']?.toString() ?? '';
      if (attractionId.isEmpty) continue;
      final periods = (item['ServiceTimes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TdxServicePeriod.fromJson)
          .toList();
      periodsByAttractionId[attractionId] = periods;
    }

    final attractions = attractionJson.map((item) {
      final attractionId = item['AttractionID']?.toString() ?? '';
      return TdxAttractionRecord.fromJson(
        item,
        servicePeriods: periodsByAttractionId[attractionId] ?? const [],
      );
    }).toList();

    stdout.writeln(
      'TDX 共 ${attractions.length} 筆景點、${serviceTimeJson.length} 筆營運時間。',
    );
    stdout.writeln('開始比對...');

    final matcher = TdxPlaceMatcher(attractions);
    final matches = placesNeedingData.map(matcher.match).toList();
    final outputDirectory = Directory(options.outputDirectory);
    await outputDirectory.create(recursive: true);
    await _writeReports(
      outputDirectory,
      allLocalPlaces: localPlaces,
      attractions: attractions,
      serviceTimeCount: serviceTimeJson.length,
      matches: matches,
    );

    final highCount = matches
        .where((match) => match.confidence == MatchConfidence.high)
        .length;
    final reviewCount = matches
        .where((match) => match.confidence == MatchConfidence.review)
        .length;
    final unmatchedCount = matches
        .where((match) => match.confidence == MatchConfidence.unmatched)
        .length;
    stdout.writeln(
      'Dry-run 完成：高可信 $highCount、需審核 $reviewCount、未匹配 $unmatchedCount。',
    );
    stdout.writeln('報告位置：${outputDirectory.absolute.path}');
    stdout.writeln('本次沒有寫入 Supabase。');
  } finally {
    client.close();
  }
}

String _requiredEnvironment(Map<String, String> environment, String name) {
  final value = environment[name]?.trim() ?? '';
  if (value.isEmpty) {
    throw StateError('缺少環境變數 $name。');
  }
  return value;
}

Future<List<LocalPlaceRecord>> _fetchSupabasePlaces(
  http.Client client, {
  required String supabaseUrl,
  required String anonKey,
}) async {
  const pageSize = 1000;
  final places = <LocalPlaceRecord>[];
  for (var start = 0; ; start += pageSize) {
    final uri = Uri.parse('$supabaseUrl/rest/v1/places').replace(
      queryParameters: {
        'select':
            'id,name,address,category,latitude,longitude,stayTime,openMinutes,closeMinutes',
        'order': 'id.asc',
      },
    );
    final response = await _sendWithRetry(
      () => client.get(
        uri,
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
          'Accept': 'application/json',
          'Range-Unit': 'items',
          'Range': '$start-${start + pageSize - 1}',
        },
      ),
      operation: 'Supabase places page $start',
    );
    _ensureSuccess(response, 'Supabase 景點讀取');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    places.addAll(
      decoded.whereType<Map<String, dynamic>>().map(LocalPlaceRecord.fromJson),
    );
    if (decoded.length < pageSize) break;
  }
  return places;
}

Future<String> _fetchTdxAccessToken(
  http.Client client, {
  required String clientId,
  required String clientSecret,
}) async {
  final response = await _sendWithRetry(
    () => client.post(
      Uri.parse(_tdxTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    ),
    operation: 'TDX access token',
  );
  _ensureSuccess(response, 'TDX Token');
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final token = decoded['access_token']?.toString() ?? '';
  if (token.isEmpty) throw StateError('TDX Token 回應缺少 access_token。');
  return token;
}

Future<List<Map<String, dynamic>>> _fetchTdxCollection(
  http.Client client, {
  required String accessToken,
  required String path,
  required List<String> select,
}) async {
  const pageSize = 500;
  final records = <Map<String, dynamic>>[];
  for (var skip = 0; ; skip += pageSize) {
    final uri = Uri.parse('$_tdxTourismBaseUrl/$path').replace(
      queryParameters: {
        r'$select': select.join(','),
        r'$top': pageSize.toString(),
        r'$skip': skip.toString(),
      },
    );
    final response = await _sendWithRetry(
      () => client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ),
      operation: 'TDX $path page $skip',
    );
    _ensureSuccess(response, 'TDX $path');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final values = decoded['value'] as List<dynamic>? ?? const [];
    records.addAll(values.whereType<Map<String, dynamic>>());
    stdout.writeln('  $path：已讀取 ${records.length} 筆');
    if (values.length < pageSize) break;
  }
  return records;
}

Future<http.Response> _sendWithRetry(
  Future<http.Response> Function() request, {
  required String operation,
}) async {
  late http.Response response;
  for (var attempt = 1; attempt <= 4; attempt++) {
    response = await request();
    if (response.statusCode != 429 && response.statusCode < 500) {
      return response;
    }
    if (attempt == 4) return response;
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    final delaySeconds = retryAfter ?? (attempt * 3);
    stderr.writeln('$operation 收到 ${response.statusCode}，$delaySeconds 秒後重試。');
    await Future<void>.delayed(Duration(seconds: delaySeconds));
  }
  return response;
}

void _ensureSuccess(http.Response response, String operation) {
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  final body = response.body.length > 500
      ? response.body.substring(0, 500)
      : response.body;
  throw HttpException('$operation 失敗：${response.statusCode} $body');
}

Future<void> _writeReports(
  Directory outputDirectory, {
  required List<LocalPlaceRecord> allLocalPlaces,
  required List<TdxAttractionRecord> attractions,
  required int serviceTimeCount,
  required List<PlaceMatchResult> matches,
}) async {
  final highMatches = matches
      .where((match) => match.confidence == MatchConfidence.high)
      .toList();
  final reviewMatches = matches
      .where((match) => match.confidence == MatchConfidence.review)
      .toList();
  final unmatched = matches
      .where((match) => match.confidence == MatchConfidence.unmatched)
      .toList();
  final autoUpdates = highMatches
      .where((match) => match.canAutoUpdate)
      .map(_proposedUpdate)
      .toList();
  final summary = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'dryRun': true,
    'supabasePlaceCount': allLocalPlaces.length,
    'placesNeedingData': matches.length,
    'tdxAttractionCount': attractions.length,
    'tdxServiceTimeCount': serviceTimeCount,
    'highConfidenceMatches': highMatches.length,
    'reviewMatches': reviewMatches.length,
    'unmatched': unmatched.length,
    'proposedAutoUpdates': autoUpdates.length,
    'coordinateFillCandidates': autoUpdates
        .where((update) => update.containsKey('latitude'))
        .length,
    'tdxVisitDurationCandidates': highMatches
        .where((match) => match.stayTimeSource == 'tdx_visit_duration')
        .length,
    'categoryRuleDurationCandidates': highMatches
        .where((match) => match.stayTimeSource == 'category_rule')
        .length,
    'openingHourCandidates': highMatches
        .where((match) => match.representativeHours != null)
        .length,
  };

  await File(
    '${outputDirectory.path}/dry_run_summary.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  await File('${outputDirectory.path}/dry_run_matches.json').writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(matches.map((match) => match.toJson()).toList()),
  );
  await File(
    '${outputDirectory.path}/dry_run_proposed_updates.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(autoUpdates));
  await File(
    '${outputDirectory.path}/dry_run_matches.csv',
  ).writeAsString(_matchesCsv(matches));
  await File(
    '${outputDirectory.path}/dry_run_review.csv',
  ).writeAsString(_matchesCsv([...reviewMatches, ...unmatched]));
}

Map<String, dynamic> _proposedUpdate(PlaceMatchResult match) {
  final localPlace = match.localPlace;
  final attraction = match.attraction!;
  final update = <String, dynamic>{
    'id': localPlace.id,
    'tdxAttractionId': attraction.id,
    'matchScore': double.parse(match.score.toStringAsFixed(4)),
  };
  if (!localPlace.hasValidCoordinates) {
    update['latitude'] = attraction.latitude;
    update['longitude'] = attraction.longitude;
  }
  if (localPlace.stayTime == null) {
    update['stayTime'] = match.proposedStayTime;
    update['stayTimeSource'] = match.stayTimeSource;
  }
  final representativeHours = match.representativeHours;
  if (representativeHours != null) {
    if (localPlace.openMinutes == null) {
      update['openMinutes'] = representativeHours.openMinutes;
    }
    if (localPlace.closeMinutes == null) {
      update['closeMinutes'] = representativeHours.closeMinutes;
    }
  }
  update['openingHoursRaw'] = match.servicePeriodsJson();
  update['serviceTimeInfo'] = attraction.serviceTimeInfo;
  return update;
}

String _matchesCsv(List<PlaceMatchResult> matches) {
  final rows = <List<Object?>>[
    [
      'db_id',
      'db_name',
      'db_address',
      'confidence',
      'score',
      'margin',
      'reason',
      'tdx_attraction_id',
      'tdx_name',
      'tdx_address',
      'latitude',
      'longitude',
      'tdx_visit_duration',
      'proposed_stay_time',
      'stay_time_source',
      'proposed_open_minutes',
      'proposed_close_minutes',
      'service_time_info',
      'service_periods_json',
      'can_auto_update',
    ],
  ];
  for (final match in matches) {
    final attraction = match.attraction;
    rows.add([
      match.localPlace.id,
      match.localPlace.name,
      match.localPlace.address,
      match.confidence.name,
      match.score.toStringAsFixed(4),
      match.margin.toStringAsFixed(4),
      match.reason,
      attraction?.id,
      attraction?.name,
      attraction?.fullAddress,
      attraction?.latitude,
      attraction?.longitude,
      attraction?.visitDuration,
      match.proposedStayTime,
      match.stayTimeSource,
      match.representativeHours?.openMinutes,
      match.representativeHours?.closeMinutes,
      attraction?.serviceTimeInfo,
      match.servicePeriodsJson(),
      match.canAutoUpdate,
    ]);
  }
  return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
}

String _csvCell(Object? value) {
  final text = value?.toString() ?? '';
  return '"${text.replaceAll('"', '""')}"';
}

class _DryRunOptions {
  final String outputDirectory;
  final int? limit;

  const _DryRunOptions({required this.outputDirectory, required this.limit});

  factory _DryRunOptions.parse(List<String> arguments) {
    var outputDirectory = 'tool/output/tdx_place_backfill';
    int? limit;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--output-dir' && index + 1 < arguments.length) {
        outputDirectory = arguments[++index];
      } else if (argument == '--limit' && index + 1 < arguments.length) {
        limit = int.tryParse(arguments[++index]);
      } else if (argument == '--help') {
        stdout.writeln(
          'dart run tool/tdx_place_backfill_dry_run.dart '
          '[--output-dir PATH] [--limit COUNT]',
        );
        exit(0);
      } else {
        throw ArgumentError('不支援的參數：$argument');
      }
    }
    return _DryRunOptions(outputDirectory: outputDirectory, limit: limit);
  }
}
