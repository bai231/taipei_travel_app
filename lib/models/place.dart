enum PlaceType {
  attraction,
  restaurant,
  accommodation;

  static PlaceType fromData({
    Object? value,
    required String category,
    required List<String> tags,
  }) {
    final normalized = [
      value?.toString() ?? '',
      category,
      ...tags,
    ].join(' ').toLowerCase();

    if (_containsAny(normalized, const [
      'accommodation',
      'hotel',
      'hostel',
      'lodging',
      '飯店',
      '旅館',
      '旅店',
      '民宿',
      '住宿',
    ])) {
      return PlaceType.accommodation;
    }
    if (_containsAny(normalized, const [
      'restaurant',
      'cafe',
      'food',
      '餐廳',
      '餐飲',
      '咖啡',
      '美食',
      '小吃',
      '夜市',
    ])) {
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

  // 預估停留時間（分鐘）
  final int stayTime;

  // 評分
  final double rating;

  // 給推薦系統使用
  final List<String> tags;

  // 價格等級
  final int priceLevel;

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
    required this.stayTime,
    required this.rating,
    required this.tags,
    required this.priceLevel,
    required this.estimatedCost,
    required this.openMinutes,
    required this.closeMinutes,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString() ?? '';
    final tags = List<String>.from(json['tags'] ?? const []);
    return Place(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      category: category,
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      image: json['image'] ?? '',
      type: PlaceType.fromData(
        value: json['placeType'] ?? json['place_type'] ?? json['kind'],
        category: category,
        tags: tags,
      ),
      county: (json['county'] ?? json['city'] ?? '').toString(),
      stayTime: (json['stayTime'] as num?)?.toInt() ?? 60,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      tags: tags,
      priceLevel: (json['priceLevel'] as num?)?.toInt() ?? 0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      openMinutes: (json['openMinutes'] as num?)?.toInt() ?? 0,
      closeMinutes: (json['closeMinutes'] as num?)?.toInt() ?? 1440,
    );
  }
}
