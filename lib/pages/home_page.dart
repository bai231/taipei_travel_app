import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/place_service.dart';
import '../services/location_service.dart';
import '../widgets/place_card.dart';
import '../pages/place_detail_page.dart';
import '../pages/itinerary_result_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PlaceService placeService = PlaceService();
  final LocationService _locationService = const LocationService(); // 📍 定位服務實例

  // 網上熱門行程清單（包含行程名稱與圖片，未來可替換為 Supabase 雲端網址）
  final List<Map<String, String>> hotTrips = const [
    {
      'name': '台北文藝慢活之旅',
      'image': 'assets/test1.jpg',
    },
    {
      'name': '九份老街與山城夕陽',
      'image': 'assets/test2.jpg',
    },
    {
      'name': '淡水河畔浪漫一日遊',
      'image': 'assets/test3.jpg',
    },
  ];

  List<Place> places = [];
  bool isLoading = true;
  String? errorMessage;

  LocationPoint? _currentUserLocation; // 📍 紀錄是否成功抓到使用者的經緯度

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    try {
      // 1. 同步平行啟動「撈取景點」與「取得手機 GPS 位置」
      final placesFuture = placeService.getPlaces();
      final locationFuture = _locationService.getCurrentLocation();

      final results = await Future.wait([placesFuture, locationFuture]);
      List<Place> fetchedPlaces = results[0] as List<Place>;
      final LocationPoint? userLocation = results[1] as LocationPoint?;

      // 2. 若有成功抓到使用者定位，計算距離並排序
      if (userLocation != null) {
        fetchedPlaces = fetchedPlaces.map((place) {
          if (place.latitude != 0.0 && place.longitude != 0.0) {
            final dist = LocationService.getDistance(
              userLocation.latitude,
              userLocation.longitude,
              place.latitude,
              place.longitude,
            );
            return place.copyWith(distanceInMeters: dist);
          }
          return place;
        }).toList();

        // 依距離由小到大（由近到遠）排序
        fetchedPlaces.sort((a, b) {
          if (a.distanceInMeters == null) return 1;
          if (b.distanceInMeters == null) return -1;
          return a.distanceInMeters!.compareTo(b.distanceInMeters!);
        });
      }

      if (!mounted) return;
      setState(() {
        places = fetchedPlaces;
        _currentUserLocation = userLocation;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 穿透全域主題背景
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 區塊一：網上大家都在玩的行程標題
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Text(
                  "網上大家都在玩的行程",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // 2. 熱門行程橫向滑動列表（半透明遮罩 + 行程名稱 + 點擊跳轉）
              SizedBox(
                height: 135,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hotTrips.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final trip = hotTrips[index];
                    final String tripName = trip['name'] ?? '精選行程';
                    final String imageSrc = trip['image'] ?? 'assets/test1.jpg';

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 點擊行程跳轉至多日橫向排程詳細頁
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItineraryResultPage(tripTitle: tripName),
                          ),
                        );
                      },
                      child: Container(
                        width: 155,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              // 底層：行程背景照片（自動辨識網路網址或本地 Asset）
                              Positioned.fill(
                                child: _buildTripImage(imageSrc),
                              ),

                              // 中層：半透明漸層黑遮罩（強化文字對比）
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.2),
                                        Colors.black.withValues(alpha: 0.65),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // 頂層：行程名稱與查看小膠囊
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0,
                                    vertical: 12.0,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        tripName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          height: 1.25,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "查看行程",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(width: 2),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white,
                                              size: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. 區塊二：景點推薦標題
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  children: [
                    Text(
                      _currentUserLocation != null ? "附近景點推薦" : "景點推薦",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_currentUserLocation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF70B19B).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF1E3A2F)),
                            SizedBox(width: 3),
                            Text(
                              "依距離排序",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1E3A2F),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Supabase 景點列表展示
              if (isLoading)
                const SizedBox(
                  height: 210,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorMessage != null)
                SizedBox(
                  height: 210,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "讀取景點失敗：$errorMessage",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (places.isEmpty)
                const SizedBox(
                  height: 210,
                  child: Center(child: Text("目前尚無景點資料")),
                )
              else
                SizedBox(
                  height: 210, // PlaceCard 高度
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: places.length,
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: PlaceCard(
                          place: place, // 點擊整張卡片即自動跳轉 PlaceDetailPage
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // 輔助函式：自動判斷是網路 URL 還是 本地 Asset
  Widget _buildTripImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF70B19B),
      child: const Center(
        child: Icon(Icons.map_outlined, color: Colors.white70, size: 36),
      ),
    );
  }
}