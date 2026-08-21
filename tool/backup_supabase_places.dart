import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> arguments) async {
  final options = _BackupOptions.parse(arguments);
  final environment = Platform.environment;
  final supabaseUrl = _requiredEnvironment(environment, 'SUPABASE_URL');
  final supabaseAnonKey = _requiredEnvironment(
    environment,
    'SUPABASE_ANON_KEY',
  );

  final client = http.Client();
  try {
    stdout.writeln('讀取 Supabase places 完整資料...');
    final places = await _fetchAllPlaces(
      client,
      supabaseUrl: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    if (places.isEmpty) {
      throw StateError('Supabase places 沒有資料，取消建立空白備份。');
    }

    final outputDirectory = Directory(options.outputDirectory);
    await outputDirectory.create(recursive: true);
    final timestamp = _formatTimestamp(DateTime.now());
    final jsonFile = File(
      '${outputDirectory.path}/places_before_tdx_$timestamp.json',
    );
    final rollbackFile = File(
      '${outputDirectory.path}/rollback_coordinates_$timestamp.sql',
    );
    final manifestFile = File(
      '${outputDirectory.path}/backup_manifest_$timestamp.json',
    );

    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(places),
    );
    await rollbackFile.writeAsString(_buildCoordinateRollbackSql(places));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'createdAt': DateTime.now().toIso8601String(),
        'table': 'public.places',
        'rowCount': places.length,
        'fullBackup': jsonFile.absolute.path,
        'coordinateRollback': rollbackFile.absolute.path,
        'scope': '完整資料備份；還原 SQL 僅還原 latitude、longitude',
      }),
    );

    stdout.writeln('備份完成：${places.length} 筆。');
    stdout.writeln('完整 JSON：${jsonFile.absolute.path}');
    stdout.writeln('座標還原 SQL：${rollbackFile.absolute.path}');
    stdout.writeln('備份清單：${manifestFile.absolute.path}');
  } finally {
    client.close();
  }
}

String _requiredEnvironment(Map<String, String> environment, String name) {
  final value = environment[name]?.trim() ?? '';
  if (value.isEmpty) throw StateError('缺少環境變數 $name。');
  return value;
}

Future<List<Map<String, dynamic>>> _fetchAllPlaces(
  http.Client client, {
  required String supabaseUrl,
  required String anonKey,
}) async {
  const pageSize = 1000;
  final places = <Map<String, dynamic>>[];
  for (var start = 0; ; start += pageSize) {
    final uri = Uri.parse('$supabaseUrl/rest/v1/places').replace(
      queryParameters: {'select': '*', 'order': 'id.asc'},
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Supabase 備份失敗：HTTP ${response.statusCode} ${response.body}',
        uri: uri,
      );
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    places.addAll(decoded.whereType<Map<String, dynamic>>());
    if (decoded.length < pageSize) break;
  }
  return places;
}

Future<http.Response> _sendWithRetry(
  Future<http.Response> Function() request, {
  required String operation,
}) async {
  const maxAttempts = 4;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final response = await request();
    if (response.statusCode != 429 && response.statusCode < 500) {
      return response;
    }
    if (attempt == maxAttempts) return response;
    final delay = Duration(seconds: attempt * 2);
    stdout.writeln('$operation 暫時失敗，${delay.inSeconds} 秒後重試...');
    await Future<void>.delayed(delay);
  }
  throw StateError('$operation 重試流程異常結束。');
}

String _buildCoordinateRollbackSql(List<Map<String, dynamic>> places) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln()
    ..writeln('CREATE TEMP TABLE places_coordinate_backup (')
    ..writeln('  id text PRIMARY KEY,')
    ..writeln('  latitude double precision,')
    ..writeln('  longitude double precision')
    ..writeln(') ON COMMIT DROP;')
    ..writeln();

  const chunkSize = 500;
  for (var start = 0; start < places.length; start += chunkSize) {
    final end = start + chunkSize < places.length
        ? start + chunkSize
        : places.length;
    buffer.writeln('INSERT INTO places_coordinate_backup VALUES');
    for (var index = start; index < end; index++) {
      final place = places[index];
      final suffix = index == end - 1 ? ';' : ',';
      buffer.writeln(
        '  (${_sqlString(place['id'])}, '
        '${_sqlNumberOrNull(place['latitude'])}, '
        '${_sqlNumberOrNull(place['longitude'])})$suffix',
      );
    }
    buffer.writeln();
  }

  buffer
    ..writeln(r'DO $rollback$')
    ..writeln('DECLARE')
    ..writeln('  matched_count integer;')
    ..writeln('BEGIN')
    ..writeln('  SELECT count(*) INTO matched_count')
    ..writeln('  FROM public.places AS place')
    ..writeln('  JOIN places_coordinate_backup AS backup')
    ..writeln('    ON place.id::text = backup.id;')
    ..writeln()
    ..writeln('  IF matched_count <> ${places.length} THEN')
    ..writeln(
      "    RAISE EXCEPTION '還原安全檢查失敗：預期 ${places.length} 筆，實際匹配 % 筆', matched_count;",
    )
    ..writeln('  END IF;')
    ..writeln('END')
    ..writeln(r'$rollback$;')
    ..writeln()
    ..writeln('UPDATE public.places AS place')
    ..writeln('SET')
    ..writeln('  latitude = backup.latitude,')
    ..writeln('  longitude = backup.longitude')
    ..writeln('FROM places_coordinate_backup AS backup')
    ..writeln('WHERE place.id::text = backup.id;')
    ..writeln()
    ..writeln('COMMIT;');
  return buffer.toString();
}

String _sqlString(Object? value) {
  final escaped = (value?.toString() ?? '').replaceAll("'", "''");
  return "'$escaped'";
}

String _sqlNumberOrNull(Object? value) {
  if (value == null) return 'NULL';
  if (value is num) return value.toString();
  final parsed = num.tryParse(value.toString());
  return parsed?.toString() ?? 'NULL';
}

String _formatTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_'
      '${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
}

class _BackupOptions {
  final String outputDirectory;

  const _BackupOptions({required this.outputDirectory});

  factory _BackupOptions.parse(List<String> arguments) {
    var outputDirectory = 'tool/output/tdx_place_backfill/backups';
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--output' && index + 1 < arguments.length) {
        outputDirectory = arguments[++index];
      } else {
        throw ArgumentError('不支援的參數：$argument');
      }
    }
    return _BackupOptions(outputDirectory: outputDirectory);
  }
}
