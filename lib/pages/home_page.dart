import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../services/place_service.dart';
import '../services/location_service.dart';
import '../widgets/place_card.dart';
import '../pages/itinerary_result_page.dart';
import '../services/language_service.dart';
import '../theme/app_typography.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.placeLoader, this.locationGateway});

  final Future<List<Place>> Function()? placeLoader;
  final CurrentLocationGateway? locationGateway;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final PlaceService placeService = PlaceService();
  CurrentLocationGateway get _locationService =>
      widget.locationGateway ?? const LocationService();

  // 網上熱門行程清單（包含行程名稱與圖片，未來可替換為 Supabase 雲端網址）
  final List<Map<String, String>> hotTrips = const [
    {'name': '台北文藝慢活之旅', 'image': 'assets/test1.jpg'},
    {'name': '九份老街與山城夕陽', 'image': 'assets/test2.jpg'},
    {'name': '淡水河畔浪漫一日遊', 'image': 'assets/test3.jpg'},
  ];

  List<Place> places = [];
  List<Place> _basePlaces = [];
  bool isLoading = true;
  bool _isRetryingLocation = false;
  bool _returningFromLocationSettings = false;
  String? errorMessage;

  LocationPoint? _currentUserLocation; // 📍 紀錄是否成功抓到使用者的經緯度

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPlaces();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _returningFromLocationSettings) {
      _returningFromLocationSettings = false;
      _retryLocation();
    }
  }

  List<Place> _recommendationsFor(
    List<Place> source,
    LocationPoint? userLocation,
  ) {
    if (userLocation == null) return source;
    final nearby = source.map((place) {
      if (place.latitude == 0 || place.longitude == 0) return place;
      final distance = LocationService.getDistance(
        userLocation.latitude,
        userLocation.longitude,
        place.latitude,
        place.longitude,
      );
      return place.copyWith(distanceInMeters: distance);
    }).toList();
    nearby.sort((a, b) {
      if (a.distanceInMeters == null) return 1;
      if (b.distanceInMeters == null) return -1;
      return a.distanceInMeters!.compareTo(b.distanceInMeters!);
    });
    return nearby;
  }

  Future<void> loadPlaces() async {
    try {
      // 1. 同步平行啟動「撈取景點」與「取得手機 GPS 位置」
      final placesFuture =
          widget.placeLoader?.call() ?? placeService.getPlaces();
      final locationFuture = _locationService.getCurrentLocation();

      final results = await Future.wait([placesFuture, locationFuture]);
      final fetchedPlaces = results[0] as List<Place>;
      final LocationPoint? userLocation = results[1] as LocationPoint?;

      if (!mounted) return;
      setState(() {
        _basePlaces = fetchedPlaces;
        places = _recommendationsFor(fetchedPlaces, userLocation);
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

  Future<void> _retryLocation() async {
    if (_isRetryingLocation || isLoading) return;
    setState(() => _isRetryingLocation = true);
    final location = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _currentUserLocation = location;
      places = _recommendationsFor(_basePlaces, location);
      _isRetryingLocation = false;
    });
  }

  Future<void> _openLocationSettings() async {
    _returningFromLocationSettings = true;
    try {
      final opened = await (await Geolocator.isLocationServiceEnabled()
          ? Geolocator.openAppSettings()
          : Geolocator.openLocationSettings());
      if (!opened) _returningFromLocationSettings = false;
    } catch (_) {
      _returningFromLocationSettings = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟定位設定，請到手機設定手動開啟定位與 App 位置權限。')),
      );
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
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Text(
                  LanguageService.tr(context, 'popular_trips'),
                  style: AppTypography.headline(),
                ),
              ),

              // 2. 熱門行程橫向滑動列表（半透明遮罩 + 行程名稱 + 點擊跳轉）
              SizedBox(
                height: 135,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hotTrips.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
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
                            builder: (_) =>
                                ItineraryResultPage(tripTitle: tripName),
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
                              Positioned.fill(child: _buildTripImage(imageSrc)),

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
                                          color: Colors.white.withValues(
                                            alpha: 0.25,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                LanguageService.tr(context, 'view_trip'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
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
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      LanguageService.tr(
                        context,
                        _currentUserLocation == null
                            ? 'spot_recommendations'
                            : 'nearby_spot_recommendations',
                      ),
                      style: AppTypography.headline(),
                    ),
                    if (_currentUserLocation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF70B19B,
                          ).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.near_me_rounded,
                              size: 12,
                              color: Color(0xFF1E3A2F),
                            ),
                            SizedBox(width: 3),
                            Text(
                              LanguageService.tr(context, 'home_distance_sort'),
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

              if (!isLoading &&
                  errorMessage == null &&
                  _currentUserLocation == null &&
                  !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '開啟手機定位並允許 App 使用位置，即可依距離顯示附近景點；目前顯示一般推薦。',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: _openLocationSettings,
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('定位設定'),
                              ),
                              TextButton.icon(
                                onPressed: _isRetryingLocation
                                    ? null
                                    : _retryLocation,
                                icon: _isRetryingLocation
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: const Text('重試定位'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                        LanguageService.tr(context, 'home_load_places_failed') + ": $errorMessage",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (places.isEmpty)
                SizedBox(
                  height: 210,
                  child: Center(child: Text(LanguageService.tr(context, 'home_no_places'))),
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
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
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
