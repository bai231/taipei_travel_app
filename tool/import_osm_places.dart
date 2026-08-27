import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;


// ============================================================
// OSM → Supabase v2
// ============================================================
//
// 全台餐飲資料匯入器
//
// v2 主要修正：
//
// 1. 不再因為 >1200 筆而 skip
// 2. 只有真正 HTTP 502/503/504/timeout 才切格
// 3. 支援舊版 cache
// 4. 支援舊版 checkpoint
// 5. 重新掃描既有區塊，避免上一版錯誤 skip 造成資料遺失
// 6. OSM ID 去重
// 7. 20m + 名稱相似度去重
// 8. Supabase batch upsert
// 9. 每個成功區塊立即保存 cache
// 10. 每個完成區塊立即保存 checkpoint
//
// ============================================================


// ============================================================
// Supabase
// ============================================================

const supabaseTable =
    'test_osm_restaurants';


// ============================================================
// Overpass servers
// ============================================================

const overpassServers = [
  'https://overpass.private.coffee/api/interpreter',
  'https://overpass-api.de/api/interpreter',
];


// ============================================================
// Taiwan bounding box
// ============================================================

const taiwanSouth =
    21.8;

const taiwanWest =
    119.2;

const taiwanNorth =
    25.5;

const taiwanEast =
    122.1;


// ============================================================
// Grid
// ============================================================

const initialGridStep =
    0.50;


// ============================================================
// HTTP
// ============================================================

const requestTimeout =
    Duration(
  seconds: 150,
);

const delayBetweenSuccessfulRequests =
    Duration(
  seconds: 3,
);

const rateLimitBaseDelay =
    Duration(
  seconds: 30,
);

const maxRetriesPerBlock =
    4;


// ============================================================
// Dedup
// ============================================================

const duplicateDistanceMeters =
    20.0;

const duplicateNameSimilarity =
    0.72;


// ============================================================
// Supabase
// ============================================================

const supabaseBatchSize =
    100;


// ============================================================
// Files
// ============================================================

const checkpointFile =
    'tool/osm_import_checkpoint.json';

const cacheFile =
    'tool/osm_import_cache.json';


// ============================================================
// main
// ============================================================

Future<void> main() async {
  try {
    await runImport();
  } catch (e, stack) {
    stderr.writeln('');
    stderr.writeln(
      '==========================================',
    );
    stderr.writeln(
      ' 匯入失敗',
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
// runImport
// ============================================================

Future<void> runImport() async {
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
    ' OSM 全台餐飲資料匯入器 v2',
  );
  print(
    '==========================================',
  );
  print('');


  // ----------------------------------------------------------
  // Cache
  // ----------------------------------------------------------

  final cachedPlaces =
      await loadCache();

  print(
    '既有 cache：'
    '${cachedPlaces.length} 筆',
  );


  // ----------------------------------------------------------
  // Checkpoint
  // ----------------------------------------------------------

  final checkpoint =
      await loadCheckpoint();

  print(
    '既有 checkpoint：'
    '${checkpoint.completedBlocks.length} 個區塊',
  );

  print(
    '待同步 Supabase：'
    '${checkpoint.pendingSupabaseKeys.length} 筆',
  );


  // ----------------------------------------------------------
  // 先處理上一輪未完成的 Supabase 資料
  // ----------------------------------------------------------

  if (checkpoint.pendingSupabaseKeys.isNotEmpty) {
    final pendingPlaces =
        cachedPlaces.where((place) {
      final key =
          '${place.osmType}:${place.osmId}';

      return checkpoint.pendingSupabaseKeys
          .contains(key);
    }).toList();


    if (pendingPlaces.isNotEmpty) {
      print('');
      print(
        '發現上一輪未完成的 Supabase 資料：'
        '${pendingPlaces.length} 筆',
      );

      print(
        '重新同步 pending 資料...',
      );

      await importToSupabase(
        supabaseUrl:
            supabaseUrl,

        supabaseKey:
            supabaseKey,

        places:
            pendingPlaces,
      );
    }


    checkpoint.pendingSupabaseKeys.clear();

    await saveCheckpoint(
      checkpoint,
    );

    print(
      '✓ pending Supabase 資料已同步完成',
    );
  }


  // ----------------------------------------------------------
  // 建立初始 grid
  // ----------------------------------------------------------

  final initialBlocks =
      generateInitialBlocks();


  print(
    '全台初始區塊：'
    '${initialBlocks.length}',
  );


  // ----------------------------------------------------------
  // v2 重要策略
  //
  // 由於 v1 將「skip」也寫成 completed，
  // 無法從舊 checkpoint 判斷哪些是正常完成。
  //
  // 因此：
  //
  // 第一次 v2 執行：
  //   重新掃描所有 initial blocks
  //
  // 但 cache 會依 OSM ID 去重。
  //
  // 後續 v2 執行：
  //   使用 checkpoint。
  //
  // ----------------------------------------------------------

  final bool firstV2Run =
      !checkpoint.v2Initialized;


  final queue =
      <GridBox>[];


  if (firstV2Run) {
    print('');
    print(
      '偵測到舊版 checkpoint。',
    );

    print(
      'v2 第一次執行將重新檢查全台初始區塊。',
    );

    print(
      '既有 cache 不會被清除。',
    );

    print('');

    queue.addAll(
      initialBlocks,
    );
  } else {
    for (final block
        in initialBlocks) {
      if (!checkpoint.completedBlocks
          .contains(block.key)) {
        queue.add(block);
      }
    }
  }


  print(
    '待處理區塊：'
    '${queue.length}',
  );


  if (queue.isEmpty) {
    print('');
    print(
      '目前沒有需要重新查詢的區塊。',
    );
  }


  // ----------------------------------------------------------
  // Queue
  // ----------------------------------------------------------

  var processed =
      0;


  while (queue.isNotEmpty) {
    final box =
        queue.removeAt(0);

    processed++;


    print('');
    print(
      '------------------------------------------',
    );

    print(
      '進度：'
      '$processed / '
      '${processed + queue.length}',
    );

    print(
      '區塊：${box.key}',
    );

    print(
      '大小：'
      '${box.width.toStringAsFixed(6)}° × '
      '${box.height.toStringAsFixed(6)}°',
    );


    try {
      final result =
          await processBlock(
        box,
      );


      // --------------------------------------------------------
      // 需要切割
      // --------------------------------------------------------

      if (result.shouldSplit) {
        final children =
            splitBlock(
          box,
        );


        print(
          '本區塊無法穩定取得。',
        );

        print(
          '自動切成 '
          '${children.length} 個更小區塊。',
        );


        queue.insertAll(
          0,
          children,
        );

        continue;
      }


      // --------------------------------------------------------
      // Overpass 成功
      // --------------------------------------------------------

      print(
        'Overpass 成功：'
        '${result.rawElementCount} 個 elements',
      );

      print(
        '符合餐飲條件：'
        '${result.places.length} 筆',
      );


      // --------------------------------------------------------
      // 重要：每個成功區塊立即處理
      //
      // 1. 先以 OSM ID + 20m/名稱相似度去重
      // 2. 寫入 cache
      // 3. 立即 upsert 這一批到 Supabase
      // 4. Supabase 成功後才把 block 標記 completed
      //
      // 如果 Supabase 暫時失敗：
      //   - cache 已經保留資料
      //   - block 不會被標記完成
      //   - 程式會停止，不會錯誤地把這個區塊當成功
      //   - 下次重跑時會再次 upsert，因為使用 OSM unique key
      // --------------------------------------------------------

      if (result.places.isNotEmpty) {
        final newPlaces =
            filterNewPlacesForImmediateUpload(
          existing:
              cachedPlaces,

          incoming:
              result.places,
        );


        print(
          '本區塊去重後新增：'
          '${newPlaces.length} 筆',
        );


        if (newPlaces.isNotEmpty) {
          // ----------------------------------------------------
          // 先記錄 pending，避免 Supabase 失敗後資料失聯
          // ----------------------------------------------------

          for (final place
              in newPlaces) {
            checkpoint.pendingSupabaseKeys.add(
              '${place.osmType}:${place.osmId}',
            );
          }

          await saveCheckpoint(
            checkpoint,
          );


          // ----------------------------------------------------
          // 先寫 cache
          // ----------------------------------------------------

          await appendToCache(
            newPlaces,
          );


          // ----------------------------------------------------
          // 立即同步 Supabase
          // ----------------------------------------------------

          print(
            '立即寫入 Supabase：'
            '${newPlaces.length} 筆',
          );


          await importToSupabase(
            supabaseUrl:
                supabaseUrl,

            supabaseKey:
                supabaseKey,

            places:
                newPlaces,
          );


          // ----------------------------------------------------
          // Supabase 成功後才更新記憶體 cache
          // ----------------------------------------------------

          cachedPlaces.addAll(
            newPlaces,
          );


          for (final place
              in newPlaces) {
            checkpoint.pendingSupabaseKeys.remove(
              '${place.osmType}:${place.osmId}',
            );
          }

          await saveCheckpoint(
            checkpoint,
          );

          print(
            '✓ 本區塊資料已安全寫入 cache + Supabase',
          );
        } else {
          print(
            '本區塊資料全部已存在或與既有資料重複，'
            '不需新增。',
          );
        }
      } else {
        print(
          '本區塊沒有符合條件的餐飲資料。',
        );
      }


      // --------------------------------------------------------
      // 只有到這裡才標記完成
      // --------------------------------------------------------

      checkpoint.completedBlocks.add(
        box.key,
      );


      await saveCheckpoint(
        checkpoint,
      );


      print(
        '✓ 區塊完成',
      );


      await Future.delayed(
        delayBetweenSuccessfulRequests,
      );
    } catch (e) {
      stderr.writeln('');
      stderr.writeln(
        '區塊處理失敗：'
        '${box.key}',
      );

      stderr.writeln(e);


      // --------------------------------------------------------
      // 這裡有一個重要差異：
      //
      // 如果是 Supabase 同步失敗，不能把「Overpass 成功」
      // 的區塊當成 Overpass 失敗來切格。
      //
      // importToSupabase() 本身已經會 retry。
      // 如果 retry 後仍失敗，直接讓主程式結束，
      // 保留 cache，讓下一次執行重新同步。
      // --------------------------------------------------------

      if (e is SupabaseSyncException) {
        stderr.writeln('');
        stderr.writeln(
          'Supabase 同步失敗。',
        );
        stderr.writeln(
          '本區塊不標記 completed。',
        );
        stderr.writeln(
          '已寫入 cache 的資料會保留。',
        );
        stderr.writeln(
          '請重新執行程式即可繼續。',
        );

        rethrow;
      }


      // --------------------------------------------------------
      // 其他區塊錯誤：重新切格
      // --------------------------------------------------------

      final children =
          splitBlock(
        box,
      );


      print(
        '此區塊不標記為完成。',
      );

      print(
        '重新切成 '
        '${children.length} 個區塊。',
      );


      queue.insertAll(
        0,
        children,
      );
    }
  }


  // ==========================================================
  // 全部掃描完成
  // ==========================================================

  print('');
  print(
    '==========================================',
  );
  print(
    ' Overpass 掃描完成',
  );
  print(
    '==========================================',
  );


  final allCached =
      await loadCache();


  print(
    'Cache 總筆數：'
    '${allCached.length}',
  );


  // ==========================================================
  // OSM ID dedup
  // ==========================================================

  final osmUnique =
      deduplicateByOsmId(
    allCached,
  );


  print(
    'OSM ID 去重後：'
    '${osmUnique.length}',
  );


  // ==========================================================
  // Nearby dedup
  // ==========================================================

  print('');
  print(
    '開始進行座標 + 名稱去重...',
  );


  final finalPlaces =
      deduplicateNearby(
    osmUnique,
  );


  print(
    '最終餐飲資料：'
    '${finalPlaces.length}',
  );


  print(
    '移除重複：'
    '${osmUnique.length - finalPlaces.length}',
  );


  // ==========================================================
  // Statistics
  // ==========================================================

  print('');
  print(
    '分類統計：',
  );


  final counts =
      <String, int>{};


  for (final place
      in finalPlaces) {
    counts[place.category] =
        (counts[place.category] ?? 0) +
        1;
  }


  final sorted =
      counts.entries.toList()
        ..sort(
          (a, b) =>
              b.value.compareTo(
                a.value,
              ),
        );


  for (final entry
      in sorted) {
    print(
      '  ${entry.key}: '
      '${entry.value}',
    );
  }


  // ==========================================================
  // Supabase
  // ==========================================================
  //
  // 每個成功區塊都已經立即 upsert。
  // 這裡不再把整個台灣 30,000+ 筆資料重新 POST 一次。
  //
  // finalPlaces 主要用來做最後統計與檢查。
  //
  // ==========================================================

  print('');
  print(
    '==========================================',
  );
  print(
    ' Supabase 即時同步確認完成',
  );
  print(
    '==========================================',
  );

  print(
    '所有已完成區塊的新增資料，'
    '均已逐區塊 upsert 到 Supabase。',
  );


  // ==========================================================
  // v2 initialized
  // ==========================================================

  checkpoint.v2Initialized =
      true;


  await saveCheckpoint(
    checkpoint,
  );


  print('');
  print(
    '==========================================',
  );
  print(
    ' 全台餐飲匯入完成',
  );
  print(
    '==========================================',
  );

  print(
    '最終筆數：'
    '${finalPlaces.length}',
  );

  print('');
}


// ============================================================
// GridBox
// ============================================================

class GridBox {
  final double south;
  final double west;
  final double north;
  final double east;


  const GridBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });


  double get width =>
      east - west;


  double get height =>
      north - south;


  String get key =>
      '${formatCoordinate(south)},'
      '${formatCoordinate(west)},'
      '${formatCoordinate(north)},'
      '${formatCoordinate(east)}';
}


String formatCoordinate(
  double value,
) {
  return value.toStringAsFixed(6);
}


// ============================================================
// Generate initial blocks
// ============================================================

List<GridBox> generateInitialBlocks() {
  final result =
      <GridBox>[];


  var south =
      taiwanSouth;


  while (south <
      taiwanNorth) {
    final north =
        math.min(
      south + initialGridStep,
      taiwanNorth,
    );


    var west =
        taiwanWest;


    while (west <
        taiwanEast) {
      final east =
          math.min(
        west + initialGridStep,
        taiwanEast,
      );


      result.add(
        GridBox(
          south: south,
          west: west,
          north: north,
          east: east,
        ),
      );


      west = east;
    }


    south = north;
  }


  return result;
}


// ============================================================
// Split block
// ============================================================

List<GridBox> splitBlock(
  GridBox box,
) {
  final midLat =
      (box.south +
          box.north) /
      2;


  final midLon =
      (box.west +
          box.east) /
      2;


  return [
    GridBox(
      south:
          box.south,
      west:
          box.west,
      north:
          midLat,
      east:
          midLon,
    ),

    GridBox(
      south:
          box.south,
      west:
          midLon,
      north:
          midLat,
      east:
          box.east,
    ),

    GridBox(
      south:
          midLat,
      west:
          box.west,
      north:
          box.north,
      east:
          midLon,
    ),

    GridBox(
      south:
          midLat,
      west:
          midLon,
      north:
          box.north,
      east:
          box.east,
    ),
  ];
}


// ============================================================
// BlockResult
// ============================================================

class BlockResult {
  final bool shouldSplit;

  final List<RestaurantPlace>
      places;

  final int rawElementCount;


  const BlockResult({
    required this.shouldSplit,
    required this.places,
    required this.rawElementCount,
  });
}


// ============================================================
// processBlock
// ============================================================

Future<BlockResult> processBlock(
  GridBox box,
) async {
  var serverIndex =
      0;


  for (
    var attempt = 1;
    attempt <= maxRetriesPerBlock;
    attempt++
  ) {
    final server =
        overpassServers[
          serverIndex %
              overpassServers.length
        ];


    print(
      'Overpass：'
      '$server',
    );


    print(
      '嘗試 '
      '$attempt / '
      '$maxRetriesPerBlock',
    );


    try {
      final response =
          await queryOverpass(
        server,
        box,
      );


      // --------------------------------------------------------
      // 429
      // --------------------------------------------------------

      if (response.statusCode ==
          429) {
        final seconds =
            rateLimitBaseDelay
                    .inSeconds *
                math.pow(
                  2,
                  attempt - 1,
                ).toInt();


        final delay =
            Duration(
          seconds:
              seconds,
        );


        print(
          'HTTP 429。',
        );


        print(
          '等待 '
          '${delay.inSeconds} 秒。',
        );


        await Future.delayed(
          delay,
        );


        serverIndex++;

        continue;
      }


      // --------------------------------------------------------
      // 502 / 503
      // --------------------------------------------------------

      if (response.statusCode ==
              502 ||
          response.statusCode ==
              503) {
        print(
          'HTTP '
          '${response.statusCode}。',
        );


        final delay =
            Duration(
          seconds:
              10 * attempt,
        );


        print(
          '等待 '
          '${delay.inSeconds} 秒後換 server。',
        );


        await Future.delayed(
          delay,
        );


        serverIndex++;

        continue;
      }


      // --------------------------------------------------------
      // 504
      // --------------------------------------------------------

      if (response.statusCode ==
          504) {
        print(
          'HTTP 504。',
        );


        return const BlockResult(
          shouldSplit:
              true,

          places:
              [],

          rawElementCount:
              0,
        );
      }


      // --------------------------------------------------------
      // 其他 HTTP error
      // --------------------------------------------------------

      if (response.statusCode !=
          200) {
        throw HttpException(
          'Overpass HTTP '
          '${response.statusCode}\n'
          '${response.body}',
        );
      }


      // --------------------------------------------------------
      // JSON
      // --------------------------------------------------------

      final decoded =
          jsonDecode(
        response.body,
      );


      if (decoded
          is! Map<String, dynamic>) {
        throw Exception(
          'Overpass JSON 格式錯誤。',
        );
      }


      final elements =
          decoded['elements'];


      if (elements is! List) {
        throw Exception(
          'Overpass 沒有 elements。',
        );
      }


      // --------------------------------------------------------
      // v2 關鍵修正
      //
      // 不再：
      //
      // if elements.length > 1200
      //     → skip
      //
      // 即使 4000、8000，
      // 只要 Overpass 成功回傳，
      // 就正常 parse。
      // --------------------------------------------------------

      final places =
          <RestaurantPlace>[];


      for (final element
          in elements) {
        final place =
            parseRestaurant(
          element,
        );


        if (place != null) {
          places.add(
            place,
          );
        }
      }


      return BlockResult(
        shouldSplit:
            false,

        places:
            places,

        rawElementCount:
            elements.length,
      );
    } on TimeoutException catch (e) {
      print(
        'Timeout：'
        '$e',
      );


      return const BlockResult(
        shouldSplit:
            true,

        places:
            [],

        rawElementCount:
            0,
      );
    } on SocketException catch (e) {
      print(
        'Socket error：'
        '$e',
      );


      if (attempt ==
          maxRetriesPerBlock) {
        return const BlockResult(
          shouldSplit:
              true,

          places:
              [],

          rawElementCount:
              0,
        );
      }


      await Future.delayed(
        Duration(
          seconds:
              10 * attempt,
        ),
      );


      serverIndex++;
    } catch (e) {
      print(
        'Overpass error：'
        '$e',
      );


      if (attempt ==
          maxRetriesPerBlock) {
        return const BlockResult(
          shouldSplit:
              true,

          places:
              [],

          rawElementCount:
              0,
        );
      }


      await Future.delayed(
        Duration(
          seconds:
              10 * attempt,
        ),
      );


      serverIndex++;
    }
  }


  return const BlockResult(
    shouldSplit:
        true,

    places:
        [],

    rawElementCount:
        0,
  );
}


// ============================================================
// Overpass query
// ============================================================

Future<http.Response> queryOverpass(
  String server,
  GridBox box,
) async {
  final bbox =
      '${box.south},'
      '${box.west},'
      '${box.north},'
      '${box.east}';


  final query = '''
[out:json][timeout:120];

(
  nwr["amenity"="restaurant"]($bbox);
  nwr["amenity"="cafe"]($bbox);
  nwr["amenity"="fast_food"]($bbox);
  nwr["amenity"="food_court"]($bbox);
  nwr["amenity"="ice_cream"]($bbox);

  nwr["shop"="pastry"]($bbox);
  nwr["shop"="confectionery"]($bbox);
  nwr["shop"="bakery"]($bbox);
);

out center tags;
''';


  return http
      .post(
        Uri.parse(
          server,
        ),
        headers: {
          'Content-Type':
              'application/x-www-form-urlencoded',

          'User-Agent':
              'taipei-travel-app/1.0 '
              '(OSM restaurant importer)',
        },
        body: {
          'data':
              query,
        },
      )
      .timeout(
        requestTimeout,
      );
}


// ============================================================
// RestaurantPlace
// ============================================================

class RestaurantPlace {
  final String osmType;
  final int osmId;

  final String name;
  final String category;

  final String? address;
  final String? cuisine;
  final String? description;
  final String? openingHours;
  final String? website;
  final String? phone;

  final double latitude;
  final double longitude;

  final Map<String, dynamic> tags;


  RestaurantPlace({
    required this.osmType,
    required this.osmId,
    required this.name,
    required this.category,
    required this.address,
    required this.cuisine,
    required this.description,
    required this.openingHours,
    required this.website,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.tags,
  });


  Map<String, dynamic> toJson() {
    return {
      'source':
          'osm',

      'osm_type':
          osmType,

      'osm_id':
          osmId,

      'name':
          name,

      'category':
          category,

      'address':
          address,

      'cuisine':
          cuisine,

      'description':
          description,

      'opening_hours':
          openingHours,

      'website':
          website,

      'phone':
          phone,

      'latitude':
          latitude,

      'longitude':
          longitude,

      'tags':
          tags,

      'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
    };
  }


  factory RestaurantPlace.fromJson(
    Map<String, dynamic> json,
  ) {
    return RestaurantPlace(
      osmType:
          json['osm_type']
              .toString(),

      osmId:
          int.parse(
        json['osm_id'].toString(),
      ),

      name:
          json['name'].toString(),

      category:
          json['category'].toString(),

      address:
          json['address']
              ?.toString(),

      cuisine:
          json['cuisine']
              ?.toString(),

      description:
          json['description']
              ?.toString(),

      openingHours:
          json['opening_hours']
              ?.toString(),

      website:
          json['website']
              ?.toString(),

      phone:
          json['phone']
              ?.toString(),

      latitude:
          double.parse(
        json['latitude']
            .toString(),
      ),

      longitude:
          double.parse(
        json['longitude']
            .toString(),
      ),

      tags:
          json['tags'] is Map
              ? Map<String, dynamic>.from(
                  json['tags'],
                )
              : {},
    );
  }
}


// ============================================================
// Parse restaurant
// ============================================================

RestaurantPlace? parseRestaurant(
  dynamic raw,
) {
  if (raw
      is! Map<String, dynamic>) {
    return null;
  }


  final osmType =
      raw['type']?.toString();

  final rawId =
      raw['id'];


  if (osmType == null ||
      rawId == null) {
    return null;
  }


  final osmId =
      rawId is int
          ? rawId
          : int.tryParse(
              rawId.toString(),
            );


  if (osmId == null) {
    return null;
  }


  final rawTags =
      raw['tags'];


  if (rawTags is! Map) {
    return null;
  }


  final tags =
      <String, dynamic>{};


  for (final entry
      in rawTags.entries) {
    tags[
        entry.key.toString()] =
        entry.value;
  }


  final name =
      cleanText(
    tags['name'],
  );


  if (name == null ||
      name.isEmpty) {
    return null;
  }


  if (shouldExclude(
    tags,
    name,
  )) {
    return null;
  }


  final category =
      determineCategory(
    tags,
  );


  if (category == null) {
    return null;
  }


  final coordinate =
      getCoordinate(
    raw,
  );


  if (coordinate == null) {
    return null;
  }


  return RestaurantPlace(
    osmType:
        osmType,

    osmId:
        osmId,

    name:
        name,

    category:
        category,

    address:
        buildAddress(
      tags,
    ),

    cuisine:
        cleanText(
      tags['cuisine'],
    ),

    description:
        cleanText(
      tags['description'] ??
          tags['description:zh'],
    ),

    openingHours:
        cleanText(
      tags['opening_hours'],
    ),

    website:
        cleanText(
      tags['website'] ??
          tags['contact:website'],
    ),

    phone:
        cleanText(
      tags['phone'] ??
          tags['contact:phone'],
    ),

    latitude:
        coordinate.$1,

    longitude:
        coordinate.$2,

    tags:
        tags,
  );
}


// ============================================================
// Exclusion
// ============================================================

bool shouldExclude(
  Map<String, dynamic> tags,
  String name,
) {
  final amenity =
      tags['amenity']
          ?.toString()
          .toLowerCase();

  final shop =
      tags['shop']
          ?.toString()
          .toLowerCase();


  final normalized =
      normalizeName(
    name,
  );


  const excludedShops = {
    'gift',
    'souvenir',
    'convenience',
    'supermarket',
    'department_store',
    'mall',
    'clothes',
    'shoes',
    'jewelry',
    'electronics',
    'mobile_phone',
    'books',
    'florist',
    'cosmetics',
    'beauty',
    'variety_store',
    'general',
  };


  if (shop != null &&
      excludedShops.contains(
        shop,
      )) {
    return true;
  }


  const excludedWords = [
    '伴手禮',
    '伴手礼',
    '土產',
    '土产',
    '名產',
    '名产',
    '特產',
    '特产',
    '禮品',
    '礼品',
    'gift shop',
    'souvenir',
    'souvenirs',
  ];


  for (final word
      in excludedWords) {
    if (normalized.contains(
      normalizeName(word),
    )) {
      return true;
    }
  }


  const excludedFoodShops = {
    'alcohol',
    'beverages',
    'butcher',
    'cheese',
    'deli',
    'seafood',
    'tea',
    'coffee',
  };


  if (shop != null &&
      excludedFoodShops.contains(
        shop,
      )) {
    return true;
  }


  const allowedAmenities = {
    'restaurant',
    'cafe',
    'fast_food',
    'food_court',
    'ice_cream',
  };


  const allowedShops = {
    'pastry',
    'confectionery',
    'bakery',
  };


  final allowed =
      (amenity != null &&
          allowedAmenities.contains(
            amenity,
          )) ||
      (shop != null &&
          allowedShops.contains(
            shop,
          ));


  return !allowed;
}


// ============================================================
// Category
// ============================================================

String? determineCategory(
  Map<String, dynamic> tags,
) {
  final amenity =
      tags['amenity']
          ?.toString()
          .toLowerCase();

  final shop =
      tags['shop']
          ?.toString()
          .toLowerCase();


  switch (amenity) {
    case 'restaurant':
      return 'restaurant';

    case 'cafe':
      return 'cafe';

    case 'fast_food':
      return 'fast_food';

    case 'food_court':
      return 'food_court';

    case 'ice_cream':
      return 'dessert';
  }


  switch (shop) {
    case 'pastry':
    case 'confectionery':
      return 'dessert';

    case 'bakery':
      return 'bakery';
  }


  return null;
}


// ============================================================
// Coordinates
// ============================================================

(double, double)? getCoordinate(
  Map<String, dynamic> raw,
) {
  final lat =
      double.tryParse(
    raw['lat']?.toString() ??
        '',
  );


  final lon =
      double.tryParse(
    raw['lon']?.toString() ??
        '',
  );


  if (lat != null &&
      lon != null) {
    return (
      lat,
      lon,
    );
  }


  final center =
      raw['center'];


  if (center is Map) {
    final centerLat =
        double.tryParse(
      center['lat']?.toString() ??
          '',
    );


    final centerLon =
        double.tryParse(
      center['lon']?.toString() ??
          '',
    );


    if (centerLat != null &&
        centerLon != null) {
      return (
        centerLat,
        centerLon,
      );
    }
  }


  return null;
}


// ============================================================
// Address
// ============================================================

String? buildAddress(
  Map<String, dynamic> tags,
) {
  final full =
      cleanText(
    tags['addr:full'] ??
        tags['address'],
  );


  if (full != null) {
    return full;
  }


  final parts =
      <String>[];


  final postcode =
      cleanText(
    tags['addr:postcode'],
  );

  final city =
      cleanText(
    tags['addr:city'],
  );

  final district =
      cleanText(
    tags['addr:district'],
  );

  final street =
      cleanText(
    tags['addr:street'],
  );

  final number =
      cleanText(
    tags['addr:housenumber'],
  );


  if (postcode != null) {
    parts.add(postcode);
  }

  if (city != null) {
    parts.add(city);
  }

  if (district != null) {
    parts.add(district);
  }

  if (street != null) {
    parts.add(street);
  }

  if (number != null) {
    parts.add(number);
  }


  if (parts.isEmpty) {
    return null;
  }


  return parts.join(' ');
}


// ============================================================
// OSM ID dedup
// ============================================================

List<RestaurantPlace> deduplicateByOsmId(
  List<RestaurantPlace> places,
) {
  final seen =
      <String>{};


  final result =
      <RestaurantPlace>[];


  for (final place
      in places) {
    final key =
        '${place.osmType}:'
        '${place.osmId}';


    if (seen.contains(key)) {
      continue;
    }


    seen.add(key);

    result.add(
      place,
    );
  }


  return result;
}


// ============================================================
// Nearby dedup
// ============================================================

List<RestaurantPlace> deduplicateNearby(
  List<RestaurantPlace> places,
) {
  final result =
      <RestaurantPlace>[];


  final buckets =
      <String, List<int>>{};


  for (final place
      in places) {
    final bx =
        (place.longitude /
                0.0003)
            .floor();


    final by =
        (place.latitude /
                0.0003)
            .floor();


    var duplicate =
        false;


    for (var dx = -1;
        dx <= 1;
        dx++) {
      for (var dy = -1;
          dy <= 1;
          dy++) {
        final key =
            '${bx + dx}:'
            '${by + dy}';


        final indexes =
            buckets[key];


        if (indexes == null) {
          continue;
        }


        for (final index
            in indexes) {
          final existing =
              result[index];


          final distance =
              distanceMeters(
            place.latitude,
            place.longitude,
            existing.latitude,
            existing.longitude,
          );


          if (distance >
              duplicateDistanceMeters) {
            continue;
          }


          final similarity =
              nameSimilarity(
            place.name,
            existing.name,
          );


          if (similarity >=
              duplicateNameSimilarity) {
            duplicate = true;


            print(
              '去除重複：'
              '"${place.name}" '
              '≈ "${existing.name}" '
              '距離='
              '${distance.toStringAsFixed(1)}m '
              '相似度='
              '${similarity.toStringAsFixed(2)}',
            );


            break;
          }
        }


        if (duplicate) {
          break;
        }
      }


      if (duplicate) {
        break;
      }
    }


    if (duplicate) {
      continue;
    }


    final newIndex =
        result.length;


    result.add(
      place,
    );


    final ownKey =
        '$bx:$by';


    buckets
        .putIfAbsent(
          ownKey,
          () => [],
        )
        .add(
          newIndex,
        );
  }


  return result;
}


// ============================================================
// Distance
// ============================================================

double distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const radius =
      6371000.0;


  final dLat =
      toRadians(
    lat2 - lat1,
  );


  final dLon =
      toRadians(
    lon2 - lon1,
  );


  final a =
      math.sin(
            dLat / 2,
          ) *
          math.sin(
            dLat / 2,
          ) +
      math.cos(
            toRadians(
              lat1,
            ),
          ) *
          math.cos(
            toRadians(
              lat2,
            ),
          ) *
          math.sin(
            dLon / 2,
          ) *
          math.sin(
            dLon / 2,
          );


  final c =
      2 *
      math.atan2(
        math.sqrt(a),
        math.sqrt(1 - a),
      );


  return radius * c;
}


double toRadians(
  double degrees,
) {
  return degrees *
      math.pi /
      180;
}


// ============================================================
// Normalize name
// ============================================================

String normalizeName(
  String value,
) {
  var result =
      value
          .toLowerCase()
          .trim();


  result =
      result.replaceAll(
    RegExp(
      r'[\s\-_・·•.,，。！？!?:：/\\()]',
    ),
    '',
  );


  const replacements = {
    '臺':
        '台',

    '臺灣':
        '台灣',

    '咖啡廳':
        '咖啡店',

    '咖啡馆':
        '咖啡店',

    '咖啡館':
        '咖啡店',
  };


  for (final entry
      in replacements.entries) {
    result =
        result.replaceAll(
      entry.key,
      entry.value,
    );
  }


  return result;
}


// ============================================================
// Name similarity
// ============================================================

double nameSimilarity(
  String a,
  String b,
) {
  final aa =
      normalizeName(
    a,
  );


  final bb =
      normalizeName(
    b,
  );


  if (aa.isEmpty ||
      bb.isEmpty) {
    return 0;
  }


  if (aa == bb) {
    return 1.0;
  }


  if (aa.contains(bb) ||
      bb.contains(aa)) {
    final shorter =
        aa.length <
                bb.length
            ? aa
            : bb;


    final longer =
        aa.length >=
                bb.length
            ? aa
            : bb;


    return shorter.length /
        longer.length;
  }


  final distance =
      levenshteinDistance(
    aa,
    bb,
  );


  final maxLength =
      math.max(
    aa.length,
    bb.length,
  );


  if (maxLength == 0) {
    return 1;
  }


  return 1 -
      distance /
          maxLength;
}


// ============================================================
// Levenshtein
// ============================================================

int levenshteinDistance(
  String a,
  String b,
) {
  if (a == b) {
    return 0;
  }


  if (a.isEmpty) {
    return b.length;
  }


  if (b.isEmpty) {
    return a.length;
  }


  var previous =
      List<int>.generate(
    b.length + 1,
    (i) => i,
  );


  for (var i = 0;
      i < a.length;
      i++) {
    final current =
        List<int>.filled(
      b.length + 1,
      0,
    );


    current[0] =
        i + 1;


    for (var j = 0;
        j < b.length;
        j++) {
      final cost =
          a.codeUnitAt(i) ==
                  b.codeUnitAt(j)
              ? 0
              : 1;


      current[j + 1] =
          math.min(
        math.min(
          current[j] + 1,
          previous[j + 1] + 1,
        ),
        previous[j] + cost,
      );
    }


    previous =
        current;
  }


  return previous[b.length];
}


// ============================================================
// Immediate upload filtering
// ============================================================
//
// 目的：
//   每個 Overpass 區塊成功後，只把「真正新的」餐飲資料
//   寫入 cache + Supabase。
//
// 判斷順序：
//   1. OSM type + OSM ID 已存在 → 不新增
//   2. 距離 <= 20m 且名稱相似度 >= 0.72 → 視為重複
//   3. 其他資料 → 保留
//
// 這樣可以避免：
//   - 相鄰區塊重疊造成重複
//   - 同一連鎖店同一地址被重複抓到
//   - 同一個 OSM object 在不同查詢中重複出現
//
// ============================================================

List<RestaurantPlace>
    filterNewPlacesForImmediateUpload({
  required List<RestaurantPlace> existing,
  required List<RestaurantPlace> incoming,
}) {
  final existingOsmIds =
      <String>{};

  for (final place
      in existing) {
    existingOsmIds.add(
      '${place.osmType}:${place.osmId}',
    );
  }


  // ----------------------------------------------------------
  // 先對本次 incoming 做 OSM ID 去重
  // ----------------------------------------------------------

  final candidates =
      <RestaurantPlace>[];

  final incomingOsmIds =
      <String>{};

  for (final place
      in incoming) {
    final key =
        '${place.osmType}:${place.osmId}';

    if (existingOsmIds.contains(key)) {
      continue;
    }

    if (!incomingOsmIds.add(key)) {
      continue;
    }

    candidates.add(place);
  }


  if (candidates.isEmpty) {
    return [];
  }


  // ----------------------------------------------------------
  // 建立既有資料的空間 bucket
  // ----------------------------------------------------------
  // 0.0003° 約 30m 左右，足以讓 20m 查詢只檢查鄰近格。
  // ----------------------------------------------------------

  const bucketSize =
      0.0003;

  final buckets =
      <String, List<RestaurantPlace>>{};

  for (final place
      in existing) {
    final bx =
        (place.longitude /
                bucketSize)
            .floor();

    final by =
        (place.latitude /
                bucketSize)
            .floor();

    buckets
        .putIfAbsent(
          '$bx:$by',
          () => [],
        )
        .add(place);
  }


  final accepted =
      <RestaurantPlace>[];


  // ----------------------------------------------------------
  // 逐筆檢查：既有資料 + 本批已接受資料
  // ----------------------------------------------------------

  for (final place
      in candidates) {
    final bx =
        (place.longitude /
                bucketSize)
            .floor();

    final by =
        (place.latitude /
                bucketSize)
            .floor();

    var duplicate =
        false;


    for (var dx = -1;
        dx <= 1;
        dx++) {
      for (var dy = -1;
          dy <= 1;
          dy++) {
        final nearby =
            buckets[
              '${bx + dx}:${by + dy}'
            ];

        if (nearby == null) {
          continue;
        }


        for (final existingPlace
            in nearby) {
          final distance =
              distanceMeters(
            place.latitude,
            place.longitude,
            existingPlace.latitude,
            existingPlace.longitude,
          );

          if (distance >
              duplicateDistanceMeters) {
            continue;
          }

          final similarity =
              nameSimilarity(
            place.name,
            existingPlace.name,
          );

          if (similarity >=
              duplicateNameSimilarity) {
            duplicate = true;

            print(
              '即時去除重複：'
              '"${place.name}" '
              '≈ "${existingPlace.name}" '
              '距離='
              '${distance.toStringAsFixed(1)}m '
              '相似度='
              '${similarity.toStringAsFixed(2)}',
            );

            break;
          }
        }

        if (duplicate) {
          break;
        }
      }

      if (duplicate) {
        break;
      }
    }


    if (duplicate) {
      continue;
    }


    accepted.add(place);


    // 加入 bucket，讓同一批後面的資料也能互相去重。
    final ownKey =
        '$bx:$by';

    buckets
        .putIfAbsent(
          ownKey,
          () => [],
        )
        .add(place);
  }


  return accepted;
}


// ============================================================
// Cache
// ============================================================

Future<List<RestaurantPlace>>
    loadCache() async {
  final file =
      File(cacheFile);


  if (!await file.exists()) {
    return [];
  }


  try {
    final text =
        await file.readAsString();


    if (text.trim().isEmpty) {
      return [];
    }


    final decoded =
        jsonDecode(
      text,
    );


    if (decoded is! List) {
      return [];
    }


    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              RestaurantPlace.fromJson(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  } catch (e) {
    stderr.writeln(
      'Cache 讀取失敗：'
      '$e',
    );


    return [];
  }
}


// ============================================================
// Append cache
// ============================================================

Future<void> appendToCache(
  List<RestaurantPlace> places,
) async {
  if (places.isEmpty) {
    return;
  }


  final file =
      File(cacheFile);


  List<dynamic> existing =
      [];


  if (await file.exists()) {
    try {
      final text =
          await file.readAsString();


      if (text.trim().isNotEmpty) {
        final decoded =
            jsonDecode(
          text,
        );


        if (decoded is List) {
          existing =
              decoded;
        }
      }
    } catch (_) {
      existing = [];
    }
  }


  final seen =
      <String>{};


  for (final item
      in existing) {
    if (item is Map) {
      final type =
          item['osm_type']
              ?.toString();


      final id =
          item['osm_id']
              ?.toString();


      if (type != null &&
          id != null) {
        seen.add(
          '$type:$id',
        );
      }
    }
  }


  for (final place
      in places) {
    final key =
        '${place.osmType}:'
        '${place.osmId}';


    if (seen.add(key)) {
      existing.add(
        place.toJson(),
      );
    }
  }


  await file.writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(existing),
    flush: true,
  );
}


// ============================================================
// Checkpoint
// ============================================================

class ImportCheckpoint {
  final Set<String>
      completedBlocks;


  final Set<String>
      pendingSupabaseKeys;


  bool v2Initialized;


  ImportCheckpoint({
    required this.completedBlocks,
    required this.pendingSupabaseKeys,
    required this.v2Initialized,
  });
}


// ============================================================
// Load checkpoint
// ============================================================

Future<ImportCheckpoint>
    loadCheckpoint() async {
  final file =
      File(checkpointFile);


  if (!await file.exists()) {
    return ImportCheckpoint(
      completedBlocks:
          {},

      pendingSupabaseKeys:
          {},

      v2Initialized:
          false,
    );
  }


  try {
    final text =
        await file.readAsString();


    final decoded =
        jsonDecode(
      text,
    );


    if (decoded is Map) {
      final blocks =
          decoded[
                  'completedBlocks']
              is List
          ? (decoded[
                    'completedBlocks']
                as List)
              .map(
                (e) =>
                    e.toString(),
              )
              .toSet()
          : <String>{};


      final pending =
          decoded[
                  'pendingSupabaseKeys']
              is List
          ? (decoded[
                    'pendingSupabaseKeys']
                as List)
              .map(
                (e) =>
                    e.toString(),
              )
              .toSet()
          : <String>{};


      final initialized =
          decoded[
                  'v2Initialized'] ==
              true;


      return ImportCheckpoint(
        completedBlocks:
            blocks,

        pendingSupabaseKeys:
            pending,

        v2Initialized:
            initialized,
      );
    }
  } catch (e) {
    stderr.writeln(
      'Checkpoint 讀取失敗：'
      '$e',
    );
  }


  return ImportCheckpoint(
    completedBlocks:
        {},

    pendingSupabaseKeys:
        {},

    v2Initialized:
        false,
  );
}


// ============================================================
// Save checkpoint
// ============================================================

Future<void> saveCheckpoint(
  ImportCheckpoint checkpoint,
) async {
  final file =
      File(checkpointFile);


  await file.writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({
      'updatedAt':
          DateTime.now()
              .toUtc()
              .toIso8601String(),

      'v2Initialized':
          checkpoint.v2Initialized,

      'completedBlocks':
          checkpoint.completedBlocks
              .toList(),

      'pendingSupabaseKeys':
          checkpoint.pendingSupabaseKeys
              .toList(),
    }),
    flush: true,
  );
}


// ============================================================
// Supabase
// ============================================================

class SupabaseSyncException implements Exception {
  final String message;

  SupabaseSyncException(
    this.message,
  );

  @override
  String toString() =>
      message;
}


// ============================================================
// Supabase
// ============================================================
//
// 每個成功區塊立即呼叫這個 function。
//
// Unique constraint：
//   (source, osm_type, osm_id)
//
// REST API：
//   ?on_conflict=source,osm_type,osm_id
//
// ============================================================

Future<void> importToSupabase({
  required String supabaseUrl,
  required String supabaseKey,
  required List<RestaurantPlace> places,
}) async {
  if (places.isEmpty) {
    return;
  }


  final baseUrl =
      supabaseUrl.replaceAll(
    RegExp(r'/$'),
    '',
  );


  final url =
      Uri.parse(
    '$baseUrl/rest/v1/'
    '$supabaseTable',
  ).replace(
    queryParameters: {
      'on_conflict':
          'source,osm_type,osm_id',
    },
  );


  var imported =
      0;


  for (
    var i = 0;
    i < places.length;
    i += supabaseBatchSize
  ) {
    final end =
        math.min(
      i + supabaseBatchSize,
      places.length,
    );


    final batch =
        places.sublist(
      i,
      end,
    );


    await uploadSupabaseBatch(
      url:
          url,

      supabaseKey:
          supabaseKey,

      places:
          batch,
    );


    imported +=
        batch.length;


    print(
      '  Supabase：'
      '$imported / '
      '${places.length}',
    );
  }
}


// ============================================================
// Supabase batch upload
// ============================================================

Future<void> uploadSupabaseBatch({
  required Uri url,
  required String supabaseKey,
  required List<RestaurantPlace> places,
}) async {
  const maxAttempts =
      5;


  for (
    var attempt = 1;
    attempt <= maxAttempts;
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
                body: jsonEncode(
                  places
                      .map(
                        (p) =>
                            p.toJson(),
                      )
                      .toList(),
                ),
              )
              .timeout(
                const Duration(
                  seconds: 60,
                ),
              );


      // --------------------------------------------------------
      // Success
      // --------------------------------------------------------

      if (response.statusCode >=
              200 &&
          response.statusCode <
              300) {
        return;
      }


      // --------------------------------------------------------
      // 409 = conflict key / schema 問題
      // --------------------------------------------------------
      //
      // 正常情況下，因為 URL 已明確指定 on_conflict，
      // 不應該再出現 duplicate key 409。
      // 如果出現，代表 Supabase 的 unique constraint
      // 與程式設定不一致，這時不應該偷偷切格或跳過資料。
      // --------------------------------------------------------

      if (response.statusCode ==
          409) {
        throw SupabaseSyncException(
          'Supabase HTTP 409。\n'
          '請確認資料表具有：\n'
          'UNIQUE(source, osm_type, osm_id)\n'
          'Response：\n'
          '${response.body}',
        );
      }


      // --------------------------------------------------------
      // 429
      // --------------------------------------------------------

      if (response.statusCode ==
          429) {
        final delaySeconds =
            10 *
                math.pow(
                  2,
                  attempt - 1,
                ).toInt();

        print(
          'Supabase HTTP 429。'
          '等待 '
          '$delaySeconds 秒後重試 '
          '($attempt/$maxAttempts)...',
        );

        await Future.delayed(
          Duration(
            seconds:
                delaySeconds,
          ),
        );

        continue;
      }


      // --------------------------------------------------------
      // 500 / 502 / 503 / 504
      // --------------------------------------------------------

      if (response.statusCode ==
              500 ||
          response.statusCode ==
              502 ||
          response.statusCode ==
              503 ||
          response.statusCode ==
              504) {
        final delaySeconds =
            5 * attempt;

        print(
          'Supabase HTTP '
          '${response.statusCode}。'
          '等待 '
          '$delaySeconds 秒後重試 '
          '($attempt/$maxAttempts)...',
        );

        await Future.delayed(
          Duration(
            seconds:
                delaySeconds,
          ),
        );

        continue;
      }


      throw SupabaseSyncException(
        'Supabase 匯入失敗：'
        'HTTP '
        '${response.statusCode}\n'
        '${response.body}',
      );
    } on SupabaseSyncException {
      rethrow;
    } on TimeoutException catch (e) {
      final delaySeconds =
          5 * attempt;

      print(
        'Supabase timeout：'
        '$e',
      );

      print(
        '等待 '
        '$delaySeconds 秒後重試 '
        '($attempt/$maxAttempts)...',
      );

      await Future.delayed(
        Duration(
          seconds:
              delaySeconds,
        ),
      );
    } on SocketException catch (e) {
      final delaySeconds =
          5 * attempt;

      print(
        'Supabase Socket error：'
        '$e',
      );

      print(
        '等待 '
        '$delaySeconds 秒後重試 '
        '($attempt/$maxAttempts)...',
      );

      await Future.delayed(
        Duration(
          seconds:
              delaySeconds,
        ),
      );
    } catch (e) {
      throw SupabaseSyncException(
        'Supabase 同步發生未預期錯誤：'
        '$e',
      );
    }
  }


  throw SupabaseSyncException(
    'Supabase batch 在 '
    '$maxAttempts 次嘗試後仍然失敗。',
  );
}


// ============================================================
// cleanText
// ============================================================

String? cleanText(
  dynamic value,
) {
  if (value == null) {
    return null;
  }


  final text =
      value
          .toString()
          .trim();


  if (text.isEmpty) {
    return null;
  }


  return text;
}