import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../algorithm/route_optimizer.dart';
import '../models/place.dart';
import '../models/scheduled_visit.dart';
import '../models/tdx_route.dart';
import '../services/itinerary_schedule_service.dart';
import '../services/map_service.dart';
import '../services/place_service.dart';
import '../services/tdx_matrix_service.dart';
import '../services/tdx_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _testOrigin = RouteStop(
    id: 'taipei-main-station',
    name: '台北車站',
    latitude: 25.0478,
    longitude: 121.5170,
    stayDurationMinutes: 0,
  );

  final _mapService = const MapService();
  final _matrixService = TdxMatrixService();
  final _tdxService = TdxService();
  final _optimizer = RouteOptimizer();
  final _scheduleService = const ItineraryScheduleService();
  final _selectedPlaceIds = <String>{};
  final _places = PlaceService().getPlaces().take(8).toList();

  GoogleMapController? _mapController;
  List<Place> _optimizedPlaces = [];
  List<_RouteLeg> _routeLegs = [];
  String? _message;
  bool _isOptimizing = false;
  bool _isLoadingRoutes = false;
  bool _isMapVisible = true;
  double _mapHeightRatio = 0.48;

  List<Place> get _selectedPlaces =>
      _places.where((place) => _selectedPlaceIds.contains(place.id)).toList();

  @override
  Widget build(BuildContext context) {
    final displayedPlaces = _optimizedPlaces.isEmpty
        ? _selectedPlaces
        : _optimizedPlaces;
    final markers = {
      _mapService
          .currentLocationMarker(
            latitude: _testOrigin.latitude,
            longitude: _testOrigin.longitude,
          )
          .copyWith(infoWindowParam: const InfoWindow(title: '測試起點：台北車站')),
      ..._mapService.placeMarkers(displayedPlaces),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('台北行程地圖'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isMapVisible = !_isMapVisible),
            icon: Icon(_isMapVisible ? Icons.map_outlined : Icons.map),
            label: Text(_isMapVisible ? '隱藏地圖' : '顯示地圖'),
          ),
          if (_isMapVisible)
            IconButton(
              tooltip: '恢復上下各半',
              onPressed: () => setState(() => _mapHeightRatio = 0.48),
              icon: const Icon(Icons.splitscreen),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!_isMapVisible) {
            return _buildPlanner(displayedPlaces);
          }

          final mapHeight = constraints.maxHeight * _mapHeightRatio;
          return Column(
            children: [
              SizedBox(
                height: mapHeight,
                child: GoogleMap(
                  initialCameraPosition: _mapService.initialCameraPosition(
                    target: LatLng(_testOrigin.latitude, _testOrigin.longitude),
                  ),
                  markers: markers,
                  polylines: displayedPlaces.length < 2
                      ? const {}
                      : {
                          _mapService.routePolylineForCoordinates([
                            LatLng(_testOrigin.latitude, _testOrigin.longitude),
                            ...displayedPlaces.map(
                              (place) =>
                                  LatLng(place.latitude, place.longitude),
                            ),
                          ]),
                        },
                  onMapCreated: (controller) => _mapController = controller,
                ),
              ),
              _buildResizeHandle(constraints.maxHeight),
              Expanded(child: _buildPlanner(displayedPlaces)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResizeHandle(double availableHeight) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          setState(() {
            _mapHeightRatio =
                (_mapHeightRatio + details.delta.dy / availableHeight).clamp(
                  0.18,
                  0.78,
                );
          });
        },
        child: Container(
          height: 22,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Container(
              width: 52,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanner(List<Place> displayedPlaces) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('測試起點：台北車站', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _places.map((place) {
            return FilterChip(
              label: Text(place.name),
              selected: _selectedPlaceIds.contains(place.id),
              onSelected: _isOptimizing || _isLoadingRoutes
                  ? null
                  : (selected) => setState(() {
                      _optimizedPlaces = [];
                      _routeLegs = [];
                      _message = null;
                      if (selected) {
                        _selectedPlaceIds.add(place.id);
                      } else {
                        _selectedPlaceIds.remove(place.id);
                      }
                    }),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isOptimizing || _isLoadingRoutes ? null : _optimizeTrip,
          icon: _isOptimizing || _isLoadingRoutes
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.alt_route),
          label: Text(
            _isOptimizing || _isLoadingRoutes
                ? (_message ?? '處理中…')
                : '使用 TDX 排序行程',
          ),
        ),
        if (!_isOptimizing && !_isLoadingRoutes && _message != null) ...[
          const SizedBox(height: 12),
          Text(_message!),
        ],
        if (displayedPlaces.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('行程順序', style: TextStyle(fontWeight: FontWeight.bold)),
          ...displayedPlaces.asMap().entries.map(
            (entry) => ListTile(
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text(entry.value.name),
              subtitle: Text(entry.value.address),
            ),
          ),
        ],
        if (_routeLegs.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'TDX 各段交通路線',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._routeLegs.map(_buildRouteLegCard),
        ],
      ],
    );
  }

  Widget _buildRouteLegCard(_RouteLeg leg) {
    final route = leg.route;
    if (route == null) {
      return Card(
        child: ExpansionTile(
          leading: const Icon(Icons.warning_amber, color: Colors.orange),
          title: Text('${leg.fromName} → ${leg.toName}'),
          subtitle: Text(
            '${_formatMinutes(leg.schedule.departureMinutes)} 出發 · '
            '${_formatMinutes(leg.schedule.arrivalMinutes)} 預估抵達',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  leg.errorMessage ?? '此路段暫時無法取得 TDX 資料。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
            _buildVisitSchedule(leg),
          ],
        ),
      );
    }

    final totalMinutes =
        leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
    final routeStart = leg.route?.startTime;
    final routeStartLabel = routeStart == null
        ? ''
        : ' · ${_formatDateTime(routeStart)} 路線開始';
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.directions_transit),
        title: Text('${leg.fromName} → ${leg.toName}'),
        subtitle: Text(
          '${_formatMinutes(leg.schedule.departureMinutes)} 可出發'
          '$routeStartLabel · '
          '${_formatMinutes(leg.schedule.arrivalMinutes)} 抵達 · '
          '含候車約 $totalMinutes 分鐘',
        ),
        children: [..._buildRouteSections(leg), _buildVisitSchedule(leg)],
      ),
    );
  }

  Widget _buildVisitSchedule(_RouteLeg leg) {
    final schedule = leg.schedule;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatMinutes(schedule.arrivalMinutes)} 抵達 ${leg.toName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (schedule.waitingMinutes > 0)
            Text(
              '等待 ${schedule.waitingMinutes} 分鐘，'
              '${_formatMinutes(schedule.visitStartMinutes)} 開始參觀',
            ),
          Text(
            '停留 ${schedule.stayMinutes} 分鐘 · '
            '${_formatMinutes(schedule.visitEndMinutes)} 離開',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRouteSections(_RouteLeg leg) {
    final route = leg.route!;
    return [
      for (var index = 0; index < route.sections.length; index++)
        _buildRouteSection(index + 1, route.sections[index]),
    ];
  }

  Widget _buildRouteSection(int index, RouteSection section) {
    final minutes = max(1, (section.travelTime / 60).ceil());
    final modeLabel = _modeLabel(section);
    final timeRange =
        section.departureTime != null && section.arrivalTime != null
        ? '${section.departureTime}–${section.arrivalTime}'
        : 'TDX 未提供班次時間';
    final departure = _placeLabel(section.departureTitle, '起點');
    final arrival = _placeLabel(section.arrivalTitle, '目的地');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text('$index', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('$departure → $arrival'),
                Text(
                  section.stopCount > 0
                      ? '$timeRange · 約 $minutes 分鐘 · 經過 ${section.stopCount} 站'
                      : '$timeRange · 約 $minutes 分鐘',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (section.destination != null &&
                    section.destination!.isNotEmpty)
                  Text(
                    '往 ${section.destination}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(RouteSection section) {
    final mode = section.mode.toLowerCase();
    if (mode.contains('pedestrian') || mode.contains('walk')) {
      return '步行';
    }
    if (mode.contains('metro') || mode.contains('subway')) {
      return section.lineName == null ? '搭乘捷運' : '搭乘捷運 ${section.lineName}';
    }
    if (mode.contains('rail') || mode.contains('train')) {
      return section.lineName == null ? '搭乘鐵路' : '搭乘 ${section.lineName}';
    }
    if (section.lineName != null && section.lineName!.isNotEmpty) {
      return '搭乘 ${section.lineName}';
    }
    return '搭乘大眾運輸';
  }

  String _placeLabel(String? value, String fallback) {
    if (value == null || value.isEmpty || value == 'place') return fallback;
    if (value == 'station') return '車站／站牌';
    return value;
  }

  String _formatMinutes(int totalMinutes) {
    final normalizedMinutes = totalMinutes % (24 * 60);
    final hour = normalizedMinutes ~/ 60;
    final minute = normalizedMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _optimizeTrip() async {
    if (_selectedPlaces.length < 2) {
      setState(() => _message = '請至少選擇兩個景點。');
      return;
    }
    if (_selectedPlaces.length > 4) {
      setState(() => _message = 'TDX 測試版最多選擇四個景點。');
      return;
    }

    setState(() {
      _isOptimizing = true;
      _message = '正在取得景點交通矩陣…';
      _routeLegs = [];
    });

    try {
      final stops = _selectedPlaces.map(RouteStop.fromPlace).toList();
      final matrix = await _matrixService.buildDurationMatrix(stops);
      if (!mounted) return;
      setState(() => _message = '正在計算最佳順序…');

      final result = _optimizer.optimizeRoute(
        stopsToVisit: stops,
        durationMatrix: matrix,
        travelTimesFromStart: _estimatedStartTimes(stops),
        startTimeMinutes: 9 * 60,
      );
      final orderedPlaces = result.sortedStops
          .map(
            (stop) =>
                _selectedPlaces.firstWhere((place) => place.id == stop.id),
          )
          .toList();

      setState(() {
        _optimizedPlaces = orderedPlaces;
        _isOptimizing = false;
        _isLoadingRoutes = true;
        _message = '排序完成，正在載入各段 TDX 路線…';
      });
      await _focusMap(orderedPlaces);
      await _loadRouteLegs(result.sortedStops);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = '規劃失敗：$error';
          _isOptimizing = false;
          _isLoadingRoutes = false;
        });
      }
    }
  }

  Future<void> _loadRouteLegs(List<RouteStop> orderedStops) async {
    final allStops = [_testOrigin, ...orderedStops];
    var nextDepartureMinutes = 9 * 60;
    final itineraryDate = _nextItineraryDate(nextDepartureMinutes);
    for (var index = 0; index < allStops.length - 1; index++) {
      final origin = allStops[index];
      final destination = allStops[index + 1];
      if (mounted) {
        setState(() {
          _message = '正在載入 ${origin.name} → ${destination.name}…';
        });
      }

      try {
        final departureTime = itineraryDate.add(
          Duration(minutes: nextDepartureMinutes),
        );
        final route = await _getRouteAtOrAfter(
          origin: origin,
          destination: destination,
          requestedDeparture: departureTime,
        );
        final travelMinutes = route == null
            ? _estimatedTravelMinutes(origin, destination)
            : _scheduleService.travelMinutesFromTdx(
                route: route,
                requestedDeparture: departureTime,
              );
        final schedule = _scheduleService.scheduleVisit(
          departureMinutes: nextDepartureMinutes,
          travelMinutes: travelMinutes,
          destination: destination,
        );
        _routeLegs.add(
          _RouteLeg(
            fromName: origin.name,
            toName: destination.name,
            schedule: schedule,
            route: route,
            errorMessage: route == null ? 'TDX 沒有提供指定時間後的可用路線。' : null,
          ),
        );
        nextDepartureMinutes = schedule.visitEndMinutes;
      } catch (_) {
        final schedule = _scheduleService.scheduleVisit(
          departureMinutes: nextDepartureMinutes,
          travelMinutes: _estimatedTravelMinutes(origin, destination),
          destination: destination,
        );
        _routeLegs.add(
          _RouteLeg(
            fromName: origin.name,
            toName: destination.name,
            schedule: schedule,
            errorMessage: 'TDX 查詢失敗，可能已達頻率限制。',
          ),
        );
        nextDepartureMinutes = schedule.visitEndMinutes;
      }

      if (mounted) setState(() {});
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    if (mounted) {
      setState(() {
        _isLoadingRoutes = false;
        _message = '行程排序與 TDX 路段載入完成。';
      });
    }
  }

  Future<List<TdxRoute>> _getRoute(
    RouteStop origin,
    RouteStop destination,
    DateTime departureTime,
  ) async {
    final originValue = '${origin.latitude},${origin.longitude}';
    final destinationValue = '${destination.latitude},${destination.longitude}';
    final cached = _tdxService.getCachedRoutingOptions(
      origin: originValue,
      destination: destinationValue,
      departureTime: departureTime,
    );
    if (cached != null) return cached;
    return _tdxService.getRoutingOptions(
      origin: originValue,
      destination: destinationValue,
      departureTime: departureTime,
    );
  }

  Future<TdxRoute?> _getRouteAtOrAfter({
    required RouteStop origin,
    required RouteStop destination,
    required DateTime requestedDeparture,
  }) async {
    const searchOffsets = [0, 15, 30];
    for (var index = 0; index < searchOffsets.length; index++) {
      final queryTime = requestedDeparture.add(
        Duration(minutes: searchOffsets[index]),
      );
      if (index > 0) {
        if (mounted) {
          setState(() {
            _message = 'TDX 正在尋找 ${origin.name} → ${destination.name} 的下一班…';
          });
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      final routes = await _getRoute(origin, destination, queryTime);
      final route = _scheduleService.selectRouteForDeparture(
        routes: routes,
        requestedDeparture: requestedDeparture,
      );
      if (route != null) return route;
    }
    return null;
  }

  DateTime _nextItineraryDate(int startMinutes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final plannedStart = today.add(Duration(minutes: startMinutes));
    return plannedStart.isAfter(now.add(const Duration(minutes: 5)))
        ? today
        : today.add(const Duration(days: 1));
  }

  List<double> _estimatedStartTimes(List<RouteStop> stops) {
    return stops.map((stop) {
      final distanceKm = _distanceInKilometers(
        _testOrigin.latitude,
        _testOrigin.longitude,
        stop.latitude,
        stop.longitude,
      );
      return 8 + distanceKm / 18 * 60;
    }).toList();
  }

  int _estimatedTravelMinutes(RouteStop origin, RouteStop destination) {
    final distanceKm = _distanceInKilometers(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    return max(1, (8 + distanceKm / 18 * 60).ceil());
  }

  double _distanceInKilometers(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const radiansPerDegree = pi / 180;
    final latitudeDifference = (endLatitude - startLatitude) * radiansPerDegree;
    final longitudeDifference =
        (endLongitude - startLongitude) * radiansPerDegree;
    final startLatitudeRadians = startLatitude * radiansPerDegree;
    final endLatitudeRadians = endLatitude * radiansPerDegree;
    final value =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(startLatitudeRadians) *
            cos(endLatitudeRadians) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);
    return 6371 * 2 * atan2(sqrt(value), sqrt(1 - value));
  }

  Future<void> _focusMap(List<Place> places) async {
    if (_mapController == null || places.isEmpty) return;
    final bounds = _mapService.boundsForCoordinates([
      LatLng(_testOrigin.latitude, _testOrigin.longitude),
      ...places.map((place) => LatLng(place.latitude, place.longitude)),
    ]);
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }
}

class _RouteLeg {
  final String fromName;
  final String toName;
  final ScheduledVisit schedule;
  final TdxRoute? route;
  final String? errorMessage;

  const _RouteLeg({
    required this.fromName,
    required this.toName,
    required this.schedule,
    this.route,
    this.errorMessage,
  });
}
