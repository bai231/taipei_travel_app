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
  final int priceLevel;

  final double estimatedCost;

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
    required this.priceLevel,
    required this.estimatedCost,
  });
}
