import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;


// ============================================================
// OSM Cache → Supabase
// ============================================================
//
// 功能：
//   將 tool/osm_import_cache.json
//   同步到 Supabase
//
// Unique key：
//   (source, osm_type, osm_id)
//
// 特點：
//   1. INSERT 新資料
//   2. UPDATE 已存在的 OSM 資料
//   3. 不會因 duplicate key 中斷
//   4. 分批處理
//   5. 支援 429 / 500 / 502 / 503 / 504
//   6. 可重複執行
//
// ============================================================


const cacheFile =
    'tool/osm_import_cache.json';


const supabaseTable =
    'test_osm_restaurants';


const batchSize =
    100;


const requestTimeout =
    Duration(
  seconds: 60,
);


const maxRetries =
    5;


// ============================================================
// main
// ============================================================

Future<void> main() async {
  try {
    await syncCacheToSupabase();
  } catch (e, stack) {
    stderr.writeln('');
    stderr.writeln(
      '==========================================',
    );
    stderr.writeln(
      ' Supabase 同步失敗',
    );
    stderr.writeln(
      '==========================================',
    );
    stderr.writeln(e);
    stderr.writeln('');
    stderr.writeln(stack);

    exitCode = 1;
  }
}


// ============================================================
// Main sync
// ============================================================

Future<void> syncCacheToSupabase() async {
  final supabaseUrl =
      Platform.environment[
          'SUPABASE_URL'];


  final supabaseKey =
      Platform.environment[
          'SUPABASE_SERVICE_ROLE_KEY'] ??
      Platform.environment[
          'SUPABASE_KEY'];


  if (supabaseUrl == null ||
      supabaseUrl.isEmpty) {
    throw Exception(
      '找不到 SUPABASE_URL。',
    );
  }


  if (supabaseKey == null ||
      supabaseKey.isEmpty) {
    throw Exception(
      '找不到 SUPABASE_SERVICE_ROLE_KEY 或 SUPABASE_KEY。',
    );
  }


  print('');
  print(
    '==========================================',
  );
  print(
    ' OSM Cache → Supabase',
  );
  print(
    '==========================================',
  );
  print('');


  // ==========================================================
  // Load cache
  // ==========================================================

  final file =
      File(cacheFile);


  if (!await file.exists()) {
    throw Exception(
      '找不到 cache：$cacheFile',
    );
  }


  final text =
      await file.readAsString();


  if (text.trim().isEmpty) {
    print(
      'Cache 是空的。',
    );

    return;
  }


  final decoded =
      jsonDecode(text);


  if (decoded is! List) {
    throw Exception(
      'Cache JSON 格式錯誤。',
    );
  }


  print(
    'Cache 原始資料：'
    '${decoded.length} 筆',
  );


  // ==========================================================
  // OSM ID dedup
  // ==========================================================

  final unique =
      <String, Map<String, dynamic>>{};


  for (final item
      in decoded) {
    if (item is! Map) {
      continue;
    }


    final data =
        Map<String, dynamic>.from(
      item,
    );


    final osmType =
        data['osm_type']
            ?.toString()
            .trim();


    final osmId =
        data['osm_id']
            ?.toString()
            .trim();


    if (osmType == null ||
        osmType.isEmpty ||
        osmId == null ||
        osmId.isEmpty) {
      continue;
    }


    // ----------------------------------------------------------
    // source 統一成 osm
    // ----------------------------------------------------------

    data['source'] =
        'osm';


    final key =
        'osm:'
        '$osmType:'
        '$osmId';


    unique[key] =
        data;
  }


  final places =
      unique.values.toList();


  print(
    'OSM ID 去重後：'
    '${places.length} 筆',
  );


  if (places.isEmpty) {
    print(
      '沒有有效資料。',
    );

    return;
  }


  // ==========================================================
  // Supabase URL
  // ==========================================================

  final baseUrl =
      supabaseUrl.replaceAll(
    RegExp(r'/$'),
    '',
  );


  // ----------------------------------------------------------
  // 關鍵：
  //
  // 明確指定 on_conflict
  //
  // 對應：
  // UNIQUE(source, osm_type, osm_id)
  //
  // ----------------------------------------------------------

  final url =
      Uri.parse(
    '$baseUrl/rest/v1/'
    '$supabaseTable'
    '?on_conflict=source,osm_type,osm_id',
  );


  print('');
  print(
    'Supabase table：'
    '$supabaseTable',
  );


  print(
    'Conflict key：'
    '(source, osm_type, osm_id)',
  );


  print(
    '準備開始 upsert...',
  );


  print('');


  // ==========================================================
  // Statistics
  // ==========================================================

  var successCount =
      0;


  var batchNumber =
      0;


  final totalBatches =
      (places.length +
              batchSize -
              1) ~/
          batchSize;


  // ==========================================================
  // Batch
  // ==========================================================

  for (
    var start = 0;
    start < places.length;
    start += batchSize
  ) {
    final end =
        start + batchSize >
                places.length
            ? places.length
            : start + batchSize;


    final batch =
        places.sublist(
      start,
      end,
    );


    batchNumber++;


    print(
      'Batch '
      '$batchNumber / '
      '$totalBatches'
      '  '
      '(${batch.length} 筆)',
    );


    await uploadBatch(
      url:
          url,

      supabaseKey:
          supabaseKey,

      batch:
          batch,
    );


    successCount +=
        batch.length;


    print(
      '  ✓ 累計：'
      '$successCount / '
      '${places.length}',
    );


    print('');
  }


  print(
    '==========================================',
  );
  print(
    ' 同步完成',
  );
  print(
    '==========================================',
  );


  print(
    '處理筆數：'
    '$successCount',
  );


  print('');
}


// ============================================================
// Upload batch
// ============================================================

Future<void> uploadBatch({
  required Uri url,
  required String supabaseKey,
  required List<Map<String, dynamic>> batch,
}) async {
  for (
    var attempt = 1;
    attempt <= maxRetries;
    attempt++
  ) {
    try {
      final response =
          await http
              .post(
                url,
                headers: {
                  'apikey':
                      supabaseKey,

                  'Authorization':
                      'Bearer '
                      '$supabaseKey',

                  'Content-Type':
                      'application/json',

                  // ------------------------------------------------
                  // 重要：
                  //
                  // merge-duplicates =
                  //     ON CONFLICT DO UPDATE
                  //
                  // 搭配 URL 上的 on_conflict。
                  // ------------------------------------------------

                  'Prefer':
                      'resolution=merge-duplicates,'
                      'return=minimal',
                },
                body:
                    jsonEncode(batch),
              )
              .timeout(
                requestTimeout,
              );


      // ========================================================
      // Success
      // ========================================================

      if (response.statusCode >=
              200 &&
          response.statusCode <
              300) {
        return;
      }


      // ========================================================
      // 409
      // ========================================================

      if (response.statusCode ==
          409) {
        stderr.writeln(
          'HTTP 409：'
          '可能存在資料庫 conflict key 問題。',
        );


        stderr.writeln(
          response.body,
        );


        // ------------------------------------------------------
        // 不要直接把整批資料丟掉。
        //
        // 如果 batch 中某一筆資料造成問題，
        // 改成逐筆 upsert。
        // ------------------------------------------------------

        print(
          '改用逐筆模式重新處理這個 batch...',
        );


        await uploadIndividually(
          url:
              url,

          supabaseKey:
              supabaseKey,

          batch:
              batch,
        );


        return;
      }


      // ========================================================
      // 429
      // ========================================================

      if (response.statusCode ==
          429) {
        final seconds =
            10 *
            (1 << (attempt - 1));


        print(
          'HTTP 429。',
        );


        print(
          '等待 '
          '$seconds 秒後重試...',
        );


        await Future.delayed(
          Duration(
            seconds:
                seconds,
          ),
        );


        continue;
      }


      // ========================================================
      // Temporary server error
      // ========================================================

      if (response.statusCode ==
              500 ||
          response.statusCode ==
              502 ||
          response.statusCode ==
              503 ||
          response.statusCode ==
              504) {
        final seconds =
            5 *
            attempt;


        print(
          'HTTP '
          '${response.statusCode}。',
        );


        print(
          '等待 '
          '$seconds 秒後重試...',
        );


        await Future.delayed(
          Duration(
            seconds:
                seconds,
          ),
        );


        continue;
      }


      // ========================================================
      // Permanent error
      // ========================================================

      throw HttpException(
        'Supabase HTTP '
        '${response.statusCode}\n'
        '${response.body}',
      );
    } on TimeoutException {
      final seconds =
          5 *
          attempt;


      print(
        'Supabase timeout。',
      );


      print(
        '等待 '
        '$seconds 秒後重試...',
      );


      await Future.delayed(
        Duration(
          seconds:
              seconds,
        ),
      );
    } on SocketException catch (e) {
      final seconds =
          5 *
          attempt;


      print(
        'Supabase connection error：'
        '$e',
      );


      print(
        '等待 '
        '$seconds 秒後重試...',
      );


      await Future.delayed(
        Duration(
          seconds:
              seconds,
        ),
      );
    }
  }


  throw Exception(
    'Supabase batch '
    '在 $maxRetries 次嘗試後仍然失敗。',
  );
}


// ============================================================
// Individual upload
// ============================================================
//
// 如果某個 batch 發生特殊 conflict，
// 就逐筆處理，避免整批失敗。
// ============================================================

Future<void> uploadIndividually({
  required Uri url,
  required String supabaseKey,
  required List<Map<String, dynamic>> batch,
}) async {
  var count =
      0;


  for (final item
      in batch) {
    await uploadSingle(
      url:
          url,

      supabaseKey:
          supabaseKey,

      item:
          item,
    );


    count++;


    print(
      '    ✓ '
      '$count / '
      '${batch.length}',
    );
  }
}


// ============================================================
// Single upload
// ============================================================

Future<void> uploadSingle({
  required Uri url,
  required String supabaseKey,
  required Map<String, dynamic> item,
}) async {
  for (
    var attempt = 1;
    attempt <= maxRetries;
    attempt++
  ) {
    try {
      final response =
          await http
              .post(
                url,
                headers: {
                  'apikey':
                      supabaseKey,

                  'Authorization':
                      'Bearer '
                      '$supabaseKey',

                  'Content-Type':
                      'application/json',

                  'Prefer':
                      'resolution=merge-duplicates,'
                      'return=minimal',
                },
                body:
                    jsonEncode([
                  item,
                ]),
              )
              .timeout(
                requestTimeout,
              );


      if (response.statusCode >=
              200 &&
          response.statusCode <
              300) {
        return;
      }


      if (response.statusCode ==
          429) {
        final seconds =
            10 *
            (1 << (attempt - 1));


        await Future.delayed(
          Duration(
            seconds:
                seconds,
          ),
        );


        continue;
      }


      if (response.statusCode ==
              500 ||
          response.statusCode ==
              502 ||
          response.statusCode ==
              503 ||
          response.statusCode ==
              504) {
        await Future.delayed(
          Duration(
            seconds:
                5 * attempt,
          ),
        );


        continue;
      }


      throw HttpException(
        '單筆 Supabase 匯入失敗：'
        'HTTP '
        '${response.statusCode}\n'
        '${response.body}\n'
        '資料：'
        '${jsonEncode(item)}',
      );
    } on TimeoutException {
      await Future.delayed(
        Duration(
          seconds:
              5 * attempt,
        ),
      );
    } on SocketException {
      await Future.delayed(
        Duration(
          seconds:
              5 * attempt,
        ),
      );
    }
  }


  throw Exception(
    '單筆資料在 '
    '$maxRetries 次嘗試後仍然失敗。',
  );
}