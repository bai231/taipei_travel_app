import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final options = _SqlOptions.parse(arguments);
  final reportFile = File(options.matchesPath);
  if (!await reportFile.exists()) {
    throw StateError('找不到 dry-run 報告：${reportFile.path}');
  }

  final decoded = jsonDecode(await reportFile.readAsString()) as List<dynamic>;
  final matches = decoded
      .whereType<Map<String, dynamic>>()
      .where(
        (match) =>
            match['confidence'] == 'high' &&
            match['reason'] == 'exact_name_and_address' &&
            match['canAutoUpdate'] == true &&
            match['latitude'] is num &&
            match['longitude'] is num,
      )
      .toList();
  if (matches.isEmpty) {
    throw StateError('報告中沒有可安全更新的完全同名同址座標。');
  }

  final outputFile = File(options.outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(_buildSql(matches));
  stdout.writeln('已產生 ${matches.length} 筆座標更新 SQL。');
  stdout.writeln('檔案位置：${outputFile.absolute.path}');
  stdout.writeln('此工具只產生 SQL，沒有連線或修改 Supabase。');
}

String _buildSql(List<Map<String, dynamic>> matches) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln()
    ..writeln('CREATE TEMP TABLE tdx_coordinate_backfill (')
    ..writeln('  id text PRIMARY KEY,')
    ..writeln('  expected_name text NOT NULL,')
    ..writeln('  expected_address text NOT NULL,')
    ..writeln('  latitude double precision NOT NULL,')
    ..writeln('  longitude double precision NOT NULL,')
    ..writeln('  tdx_attraction_id text NOT NULL')
    ..writeln(') ON COMMIT DROP;')
    ..writeln();

  const chunkSize = 500;
  for (var start = 0; start < matches.length; start += chunkSize) {
    final end = start + chunkSize < matches.length
        ? start + chunkSize
        : matches.length;
    buffer.writeln('INSERT INTO tdx_coordinate_backfill VALUES');
    for (var index = start; index < end; index++) {
      final match = matches[index];
      final suffix = index == end - 1 ? ';' : ',';
      buffer.writeln(
        "  (${_sqlString(match['dbId'])}, "
        "${_sqlString(match['dbName'])}, "
        "${_sqlString(match['dbAddress'])}, "
        "${(match['latitude'] as num).toDouble()}, "
        "${(match['longitude'] as num).toDouble()}, "
        "${_sqlString(match['tdxAttractionId'])})$suffix",
      );
    }
    buffer.writeln();
  }

  buffer
    ..writeln(r'DO $backfill$')
    ..writeln('DECLARE')
    ..writeln('  matched_count integer;')
    ..writeln('BEGIN')
    ..writeln('  SELECT count(*) INTO matched_count')
    ..writeln('  FROM public.places AS place')
    ..writeln('  JOIN tdx_coordinate_backfill AS source')
    ..writeln('    ON place.id::text = source.id')
    ..writeln('   AND place.name = source.expected_name')
    ..writeln('   AND place.address = source.expected_address;')
    ..writeln()
    ..writeln('  IF matched_count <> ${matches.length} THEN')
    ..writeln(
      "    RAISE EXCEPTION '安全檢查失敗：預期 ${matches.length} 筆，實際匹配 % 筆', matched_count;",
    )
    ..writeln('  END IF;')
    ..writeln('END')
    ..writeln(r'$backfill$;')
    ..writeln()
    ..writeln('UPDATE public.places AS place')
    ..writeln('SET')
    ..writeln('  latitude = COALESCE(place.latitude, source.latitude),')
    ..writeln('  longitude = COALESCE(place.longitude, source.longitude)')
    ..writeln('FROM tdx_coordinate_backfill AS source')
    ..writeln('WHERE place.id::text = source.id')
    ..writeln('  AND place.name = source.expected_name')
    ..writeln('  AND place.address = source.expected_address')
    ..writeln('  AND (place.latitude IS NULL OR place.longitude IS NULL);')
    ..writeln()
    ..writeln('SELECT')
    ..writeln('  count(*) AS remaining_missing_coordinates')
    ..writeln('FROM public.places')
    ..writeln('WHERE latitude IS NULL OR longitude IS NULL;')
    ..writeln()
    ..writeln('COMMIT;');
  return buffer.toString();
}

String _sqlString(Object? value) {
  final escaped = (value?.toString() ?? '').replaceAll("'", "''");
  return "'$escaped'";
}

class _SqlOptions {
  final String matchesPath;
  final String outputPath;

  const _SqlOptions({required this.matchesPath, required this.outputPath});

  factory _SqlOptions.parse(List<String> arguments) {
    var matchesPath = 'tool/output/tdx_place_backfill/dry_run_matches.json';
    var outputPath =
        'tool/output/tdx_place_backfill/apply_exact_coordinate_matches.sql';
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--matches' && index + 1 < arguments.length) {
        matchesPath = arguments[++index];
      } else if (argument == '--output' && index + 1 < arguments.length) {
        outputPath = arguments[++index];
      } else {
        throw ArgumentError('不支援的參數：$argument');
      }
    }
    return _SqlOptions(matchesPath: matchesPath, outputPath: outputPath);
  }
}
