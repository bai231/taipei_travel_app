class Place {
  final String id;
  final String name;
  final String category;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String image;

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
    required this.stayTime,
    required this.rating,
    required this.tags,
    //required this.priceLevel,
    required this.estimatedCost,
    required this.openMinutes,
    required this.closeMinutes,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      image: json['image'] ?? '',
      stayTime: json['stayTime'] ?? 60,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      tags: List<String>.from(json['tags'] ?? []),
      //priceLevel: json['priceLevel'] ?? 0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      openMinutes: json['openMinutes'] ?? 0,
      closeMinutes: json['closeMinutes'] ?? 1440,
    );
  }
}
