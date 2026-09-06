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
  final String openingHoursRaw;
  final bool? openingHoursProvided;

  bool get hasKnownOpeningHours =>
      openingHoursProvided != false &&
      openMinutes >= 0 &&
      closeMinutes <= 1440 &&
      closeMinutes > openMinutes &&
      (openMinutes != 0 ||
          closeMinutes != 1440 ||
          openingHoursRaw.trim() == '24/7');

  // 預估停留時間（分鐘）
  final int stayTime;

  // 評分
  final double rating;

  // 給推薦系統使用
  final List<String> tags;

  // 價格等級
  //final int priceLevel;

  // 預估花費（每人每次）
  final double estimatedCost;

  // 營業時間（分鐘）
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
    this.openingHoursRaw = '',
    this.openingHoursProvided,
    required this.stayTime,
    required this.rating,
    required this.tags,
    //required this.priceLevel,
    required this.estimatedCost,
    required this.openMinutes,
    required this.closeMinutes,
  });

  factory Place.fromJson(
    Map<String, dynamic> json, {
    PlaceType? forcedType,
    String? idPrefix,
  }) {
    Object? firstValue(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) return value;
      }
      return null;
    }

    num? numberValue(List<String> keys) {
      final value = firstValue(keys);
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '');
    }

    num? parseNumber(Object? value) {
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '');
    }

    String combinedAddress() {
      final directAddress =
          firstValue(['address', 'Address'])?.toString() ?? '';
      if (directAddress.trim().isNotEmpty) return directAddress;

      var result = '';
      for (final key in ['縣市名稱', '行政區(鄉鎮區)名稱', '街道名稱']) {
        final part = json[key]?.toString().trim() ?? '';
        if (part.isEmpty || result.endsWith(part)) continue;
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
          '',
      stayTime: numberValue(['stayTime', 'stay_time'])?.toInt() ?? 60,
      openingHoursRaw:
          firstValue(['opening_hours', 'OpenTime'])?.toString() ?? '',
      openingHoursProvided:
          (numberValue(['openMinutes', 'open_minutes']) != null &&
              numberValue(['closeMinutes', 'close_minutes']) != null) ||
          firstValue(['opening_hours', 'OpenTime'])?.toString().trim() ==
              '24/7',
      rating: numberValue(['rating', 'Rating'])?.toDouble() ?? 0.0,
      tags: tags,
      //priceLevel: (json['priceLevel'] as num?)?.toInt() ?? 0,
      estimatedCost:
          numberValue(['estimatedCost', 'estimated_cost'])?.toDouble() ?? 0.0,
      openMinutes: numberValue(['openMinutes', 'open_minutes'])?.toInt() ?? 0,
      closeMinutes:
          numberValue(['closeMinutes', 'close_minutes'])?.toInt() ?? 1440,
    );
  }

  Place copyWith({String? county}) {
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
      openingHoursRaw: openingHoursRaw,
      openingHoursProvided: openingHoursProvided,
      stayTime: stayTime,
      rating: rating,
      tags: tags,
      estimatedCost: estimatedCost,
      openMinutes: openMinutes,
      closeMinutes: closeMinutes,
    );
  }
}
