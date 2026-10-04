import 'dart:convert';

enum PlaceType {
  attraction,
  restaurant,
  accommodation;

  static PlaceType fromData({
    Object? value,
    String name = '',
    required String category,
    required List<String> tags,
  }) {
    final explicitType = [
      value?.toString() ?? '',
      category,
      ...tags,
    ].join(' ').toLowerCase();
    final normalizedName = name.toLowerCase();

    const accommodationKeywords = [
      'accommodation',
      'hotel',
      'hostel',
      'lodging',
      'guest_house',
      'guesthouse',
      'motel',
      'resort',
      '飯店',
      '旅館',
      '旅店',
      '民宿',
      '住宿',
      '青年旅館',
      '汽車旅館',
      '度假村',
    ];

    const restaurantKeywords = [
      'restaurant',
      'cafe',
      'food',
      '餐廳',
      '餐飲',
      '咖啡',
      '美食',
      '小吃',
      '夜市',
    ];

    if (_containsAny(explicitType, accommodationKeywords)) {
      return PlaceType.accommodation;
    }

    if (_containsAny(explicitType, restaurantKeywords)) {
      return PlaceType.restaurant;
    }

    if (_containsAny(normalizedName, accommodationKeywords)) {
      return PlaceType.accommodation;
    }

    if (_containsAny(normalizedName, restaurantKeywords)) {
      return PlaceType.restaurant;
    }

    return PlaceType.attraction;
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }
}

/// 單一營業時間區間
///
/// Google Places 的 day：
/// 0 = Sunday
/// 1 = Monday
/// ...
/// 6 = Saturday
class OpeningPeriod {
  final int openDay;
  final int closeDay;
  final int openMinutes;
  final int closeMinutes;

  const OpeningPeriod({
    required this.openDay,
    required this.closeDay,
    required this.openMinutes,
    required this.closeMinutes,
  });

  factory OpeningPeriod.fromJson(Map<String, dynamic> json) {
    final openRaw = json['open'];
    final closeRaw = json['close'];

    if (openRaw is! Map || closeRaw is! Map) {
      throw const FormatException('Invalid opening period');
    }

    final open = Map<String, dynamic>.from(openRaw);
    final close = Map<String, dynamic>.from(closeRaw);

    return OpeningPeriod(
      openDay: _parseDay(open['day']),
      closeDay: _parseDay(close['day']),
      openMinutes: _timeToMinutes(open['time']),
      closeMinutes: _timeToMinutes(close['time']),
    );
  }

  static int _parseDay(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _timeToMinutes(Object? value) {
    final time = value?.toString().trim() ?? '';

    if (time.length != 4) {
      return 0;
    }

    final hour = int.tryParse(time.substring(0, 2)) ?? 0;
    final minute = int.tryParse(time.substring(2, 4)) ?? 0;

    return hour * 60 + minute;
  }
}

class Place {
  final String id;
  final String name;
  final String category;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String image;
  final PlaceType type;
  final String county;
  final String district;

  final String openingHoursRaw;

  /// 給前端顯示使用
  ///
  /// 例如：
  /// 星期一: 06:00 – 20:00
  final List<String> openingHours;

  /// 給排程邏輯使用
  ///
  /// 例如：
  /// Monday 06:00 → 20:00
  final List<OpeningPeriod> openingPeriods;

  final bool? openingHoursProvided;
  final String phone;
  final String website;

  final double? distanceInMeters; // 與使用者位置的距離（公尺）

  String get formattedDistance {
    if (distanceInMeters == null) return '';

    if (distanceInMeters! < 1000) {
      return '${distanceInMeters!.round()}m';
    } else {
      return '${(distanceInMeters! / 1000).toStringAsFixed(1)}km';
    }
  }

  bool get hasKnownOpeningHours =>
      openingHoursProvided != false &&
      (openingPeriods.isNotEmpty ||
          (openMinutes >= 0 &&
              closeMinutes <= 1440 &&
              closeMinutes > openMinutes &&
              (openMinutes != 0 ||
                  closeMinutes != 1440 ||
                  openingHoursRaw.trim() == '24/7')));

  // 預估停留時間（分鐘）
  final int stayTime;

  // 評分
  final double rating;

  // 給推薦系統使用
  final List<String> tags;

  // 價格等級
  final int price_level;

  // 預估花費（每人每次）
  //final double estimatedCost;

  // 舊版營業時間（分鐘）
  // 暫時保留，避免其他既有程式碼立刻出錯
  final int openMinutes;
  final int closeMinutes;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.image,
    this.type = PlaceType.attraction,
    this.county = '',
    this.district = '',
    this.openingHoursRaw = '',
    this.openingHours = const [],
    this.openingPeriods = const [],
    this.openingHoursProvided,
    this.phone = '',
    this.website = '',
    this.distanceInMeters,
    required this.stayTime,
    required this.rating,
    required this.tags,
    required this.price_level,
    //required this.estimatedCost,
    required this.openMinutes,
    required this.closeMinutes,
  });

  /// 取得某一天所有營業時段
  ///
  /// Dart DateTime.weekday：
  /// Monday = 1
  /// ...
  /// Sunday = 7
  ///
  /// Google：
  /// Sunday = 0
  /// Monday = 1
  /// ...
  /// Saturday = 6
  List<OpeningPeriod> getOpeningPeriodsForDate(DateTime date) {
    final googleDay = date.weekday % 7;

    return openingPeriods
        .where((period) => period.openDay == googleDay)
        .toList();
  }

  factory Place.fromJson(
    Map<String, dynamic> json, {
    PlaceType? forcedType,
    String? idPrefix,
  }) {
    Object? firstValue(List<String> keys) {
      for (final key in keys) {
        final value = json[key];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value;
        }
      }

      return null;
    }

    num? numberValue(List<String> keys) {
      final value = firstValue(keys);

      if (value is num) {
        return value;
      }

      return num.tryParse(value?.toString() ?? '');
    }

    num? parseNumber(Object? value) {
      if (value is num) {
        return value;
      }

      return num.tryParse(value?.toString() ?? '');
    }

    Object? nestedValue(Object? source, List<String> keys) {
      if (source is! Map) {
        return null;
      }

      for (final key in keys) {
        final value = source[key];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value;
        }
      }

      return null;
    }

    List<String> stringList(Object? value) {
      if (value == null) {
        return const [];
      }

      if (value is String) {
        final trimmed = value.trim();

        if (trimmed.isEmpty) {
          return const [];
        }

        if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
            (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
          try {
            return stringList(jsonDecode(trimmed));
          } catch (_) {
            // 不是 JSON 時，繼續按一般文字處理。
          }
        }

        return trimmed
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }

      if (value is Iterable) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      if (value is Map) {
        return stringList(
          nestedValue(value, const [
            'weekday_text',
            'weekdayText',
            'weekday_descriptions',
            'weekdayDescriptions',
          ]),
        );
      }

      return const [];
    }

    List<OpeningPeriod> openingPeriodList(Object? value) {
      if (value == null) {
        return const [];
      }

      Object? decodedValue = value;

      // 如果 Supabase / CSV 將 JSON 存成字串，
      // 先將它 decode 成 Map。
      if (decodedValue is String) {
        final trimmed = decodedValue.trim();

        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            decodedValue = jsonDecode(trimmed);
          } catch (_) {
            return const [];
          }
        } else {
          return const [];
        }
      }

      Object? rawPeriods;

      if (decodedValue is Map) {
        rawPeriods = nestedValue(decodedValue, const ['periods']);
      } else if (decodedValue is Iterable) {
        rawPeriods = decodedValue;
      }

      if (rawPeriods is! Iterable) {
        return const [];
      }

      final periods = <OpeningPeriod>[];

      for (final item in rawPeriods) {
        if (item is! Map) {
          continue;
        }

        try {
          periods.add(OpeningPeriod.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // 單一 period 格式錯誤時略過，
          // 不影響其他正確的營業時間。
        }
      }

      return periods;
    }

    List<OpeningPeriod> openingPeriodsFromWeekdayText(
      List<String> weekdayText,
    ) {
      final periods = <OpeningPeriod>[];

      final dayMap = <String, int>{
        '星期一': 1,
        '星期二': 2,
        '星期三': 3,
        '星期四': 4,
        '星期五': 5,
        '星期六': 6,
        '星期日': 0,
      };

      for (final line in weekdayText) {
        final trimmed = line.trim();

        if (trimmed.isEmpty) {
          continue;
        }

        int? day;

        for (final entry in dayMap.entries) {
          if (trimmed.startsWith(entry.key)) {
            day = entry.value;
            break;
          }
        }

        if (day == null) {
          continue;
        }

        // 休息日不建立 OpeningPeriod
        if (trimmed.contains('休息') ||
            trimmed.contains('公休') ||
            trimmed.contains('不營業')) {
          continue;
        }

        // 24 小時營業
        if (trimmed.contains('24 小時營業') ||
            trimmed.contains('24小時營業') ||
            trimmed.toLowerCase().contains('open 24 hours')) {
          periods.add(
            OpeningPeriod(
              openDay: day,
              closeDay: day,
              openMinutes: 0,
              closeMinutes: 1440,
            ),
          );

          continue;
        }

        // 一般格式，例如：
        // 星期一: 09:00 – 17:00
        final matches = RegExp(
          r'(\d{1,2}):(\d{2})\s*[–—－~-]\s*(\d{1,2}):(\d{2})',
        ).allMatches(trimmed);

        for (final match in matches) {
          final openHour = int.tryParse(match.group(1) ?? '');
          final openMinute = int.tryParse(match.group(2) ?? '');
          final closeHour = int.tryParse(match.group(3) ?? '');
          final closeMinute = int.tryParse(match.group(4) ?? '');

          if (openHour == null ||
              openMinute == null ||
              closeHour == null ||
              closeMinute == null) {
            continue;
          }

          periods.add(
            OpeningPeriod(
              openDay: day,
              closeDay: day,
              openMinutes: openHour * 60 + openMinute,
              closeMinutes: closeHour * 60 + closeMinute,
            ),
          );
        }
      }

      return periods;
    }

    String combinedAddress() {
      final directAddress =
          firstValue(['address', 'Address'])?.toString() ?? '';

      if (directAddress.trim().isNotEmpty) {
        return directAddress;
      }

      var result = '';

      for (final key in ['縣市名稱', '行政區(鄉鎮區)名稱', '街道名稱']) {
        final part = json[key]?.toString().trim() ?? '';

        if (part.isEmpty || result.endsWith(part)) {
          continue;
        }

        if (part.startsWith(result)) {
          result = part;
        } else {
          result += part;
        }
      }

      return result;
    }

    final position = json['Position'] is Map
        ? Map<String, dynamic>.from(json['Position'] as Map)
        : const <String, dynamic>{};

    final picture = json['Picture'] is Map
        ? Map<String, dynamic>.from(json['Picture'] as Map)
        : const <String, dynamic>{};

    final rawTags = json['tags'];

    final rawOpeningHours = firstValue([
      'opening_hours',
      'openingHours',
      'regular_opening_hours',
      'regularOpeningHours',
      'current_opening_hours',
      'currentOpeningHours',
      'weekday_text',
      'weekday_descriptions',
      'weekdayDescriptions',
      'OpenTime',
      'ServiceTime',
      '營業時間',
    ]);

    // 前端顯示文字
    final openingHours = stringList(rawOpeningHours);

    // 優先使用 API 提供的 periods。
    final structuredOpeningPeriods = openingPeriodList(rawOpeningHours);

    // 如果沒有 periods，才從 weekday_text 嘗試解析。
    final openingPeriods = structuredOpeningPeriods.isNotEmpty
        ? structuredOpeningPeriods
        : openingPeriodsFromWeekdayText(openingHours);

    String tagValue(String key) =>
        rawTags is Map ? rawTags[key]?.toString().trim() ?? '' : '';

    final tags = rawTags is Iterable
        ? rawTags.map((tag) => tag.toString()).toList()
        : rawTags is Map
        ? rawTags.entries.map((entry) => '${entry.key}:${entry.value}').toList()
        : rawTags == null || rawTags.toString().trim().isEmpty
        ? <String>[]
        : rawTags
              .toString()
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();

    final name =
        firstValue([
          'name',
          'RestaurantName',
          'HotelName',
          '資料名稱',
        ])?.toString() ??
        '';

    final category =
        firstValue([
          'category',
          'Class',
          'class',
          'cuisine',
          'type',
          'osm_type',
          '資料類型',
        ])?.toString() ??
        '';

    final rawId =
        firstValue([
          'id',
          'RestaurantID',
          'HotelID',
          'osm_id',
          'source_id',
          '唯一識別碼',
        ])?.toString() ??
        '$name-${combinedAddress()}';

    final latitude =
        numberValue(['latitude', 'lat', 'PositionLat']) ??
        parseNumber(position['PositionLat']) ??
        0;

    final longitude =
        numberValue(['longitude', 'lon', 'lng', 'PositionLon']) ??
        parseNumber(position['PositionLon']) ??
        0;

    return Place(
      id: idPrefix == null ? rawId : '$idPrefix:$rawId',

      name: name,

      category: category,

      description:
          firstValue(['description', 'Description', '文字描述'])?.toString() ?? '',

      address: combinedAddress(),

      latitude: latitude.toDouble(),

      longitude: longitude.toDouble(),

      image:
          firstValue(['image', 'image_url', 'PictureUrl1'])?.toString() ??
          picture['PictureUrl1']?.toString() ??
          '',

      type:
          forcedType ??
          PlaceType.fromData(
            value: firstValue(['placeType', 'place_type', 'kind']),
            name: name,
            category: category,
            tags: tags,
          ),

      county:
          firstValue([
            'county',
            'city',
            'City',
            'location',
            '縣市名稱',
          ])?.toString() ??
          tagValue('addr:city'),

      district:
          firstValue(['district', 'town', 'Town', '行政區(鄉鎮區)名稱'])?.toString() ??
          tagValue('addr:district'),

      stayTime: numberValue(['stayTime', 'stay_time'])?.toInt() ?? 60,

      openingHoursRaw: rawOpeningHours is String
          ? rawOpeningHours
          : openingHours.join('\n'),

      openingHours: openingHours,

      openingPeriods: openingPeriods,

      openingHoursProvided:
          (numberValue(['openMinutes', 'open_minutes']) != null &&
              numberValue(['closeMinutes', 'close_minutes']) != null) ||
          openingHours.isNotEmpty ||
          openingPeriods.isNotEmpty,

      phone:
          firstValue([
            'phone',
            'phone_number',
            'phoneNumber',
            'telephone',
            'Telephone',
            'tel',
            'Tel',
            'formatted_phone_number',
            'formattedPhoneNumber',
            'national_phone_number',
            'nationalPhoneNumber',
            'international_phone_number',
            'internationalPhoneNumber',
            'Phone',
            'PhoneNumber',
            '電話',
          ])?.toString() ??
          '',

      website:
          firstValue([
            'website',
            'website_url',
            'websiteUrl',
            'website_uri',
            'websiteUri',
            'WebsiteUrl',
            '網址',
          ])?.toString() ??
          '',

      rating: numberValue(['rating', 'Rating'])?.toDouble() ?? 0.0,

      tags: tags,

      price_level:
          numberValue(['price_level', 'priceLevel', 'PriceLevel'])?.toInt() ??
          0,

      //estimatedCost:
      //    numberValue(['estimatedCost', 'estimated_cost'])?.toDouble() ?? 0.0,

      // 舊格式先保留
      openMinutes: numberValue(['openMinutes', 'open_minutes'])?.toInt() ?? 0,

      closeMinutes:
          numberValue(['closeMinutes', 'close_minutes'])?.toInt() ?? 1440,
    );
  }

  Place copyWith({String? county, double? distanceInMeters}) {
    return Place(
      id: id,
      name: name,
      category: category,
      description: description,
      address: address,
      latitude: latitude,
      longitude: longitude,
      image: image,
      type: type,
      county: county ?? this.county,
      district: district,
      openingHoursRaw: openingHoursRaw,
      openingHours: openingHours,
      openingPeriods: openingPeriods,
      openingHoursProvided: openingHoursProvided,
      phone: phone,
      website: website,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      stayTime: stayTime,
      rating: rating,
      tags: tags,
      price_level: price_level,
      //estimatedCost: estimatedCost,

      // 舊格式先保留
      openMinutes: openMinutes,
      closeMinutes: closeMinutes,
    );
  }
}
