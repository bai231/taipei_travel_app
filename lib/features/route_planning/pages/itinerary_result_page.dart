import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/place.dart';
import '../../../models/trip_place_constraint.dart';
import '../../../models/visit_preferences.dart';
import '../../../services/live_itinerary_tracking_service.dart';
import '../../../services/location_service.dart';
import '../../../services/taiwan_county_resolver.dart';
import '../../../services/trip_notification_service.dart';
import '../../../services/weather_advisory_service.dart';
import '../../../widgets/trip/visit_preferences_dialog.dart';
import '../../../widgets/trip/save_itinerary_button.dart';
import '../models/route_day.dart';
import '../models/route_itinerary.dart';
import '../models/route_travel_mode.dart';
import '../models/route_visit.dart';
import '../models/travel_leg.dart';
import '../widgets/travel_leg_card.dart';
import '../widgets/trip_map_panel.dart';

typedef AddItineraryPlaces =
    Future<List<Place>> Function(
      BuildContext context,
      Set<String> selectedPlaceIds,
    );
typedef RecalculateItinerary =
    Future<RouteItinerary> Function(
      List<TripPlaceConstraint> constraints,
      Map<RouteLegKey, RouteTravelMode> travelModeOverrides,
      RouteItinerary previousItinerary,
    );
typedef RequestIndoorItineraryAlternatives =
    Future<void> Function(WeatherIndoorItineraryRequest request);

class ItineraryResultPage extends StatefulWidget {
  final RouteItinerary itinerary;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final AddItineraryPlaces? onAddPlace;
  final RecalculateItinerary? onRecalculate;

  /// Integration point for an AI-powered indoor itinerary recommendation.
  /// This page asks for consent but deliberately does not change the itinerary.
  final RequestIndoorItineraryAlternatives?
  onRequestIndoorItineraryAlternatives;

  const ItineraryResultPage({
    super.key,
    required this.itinerary,
    this.onEdit,
    this.onExport,
    this.onAddPlace,
    this.onRecalculate,
    this.onRequestIndoorItineraryAlternatives,
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  static const _dayWidth = 280.0;
  static const _timeWidth = 64.0;
  static const _hourHeight = 92.0;
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();
  final List<Place> _pendingPlaces = [];
  final _tripTracker = LiveItineraryTrackingService();
  final _notificationService = TripNotificationService();
  late final WeatherAdvisoryService _weatherAdvisoryService;
  late final Future<TaiwanCountyResolver> _countyResolver;
  final _liveDayReplanner = LiveDayItineraryReplanner();

  late RouteItinerary _itinerary;
  late List<TripPlaceConstraint> _constraints;
  late Map<RouteLegKey, RouteTravelMode> _travelModeOverrides;
  int _selectedDayIndex = 0;
  int? _mapDayIndex;
  bool _isMapVisible = false;
  bool _isRecalculating = false;
  bool _isTracking = false;
  bool _isStartingWeatherFlow = false;
  bool _hasReportedWeatherError = false;
  bool _isLiveReplanning = false;
  LocationPoint? _currentLocation;
  List<LocationPoint> _trackedRoute = const [];
  double _mapHeightRatio = 0.34;

  int? get _validMapDayIndex =>
      _mapDayIndex != null && _mapDayIndex! < _itinerary.days.length
      ? _mapDayIndex
      : null;

  RouteDay get _mapDay =>
      _itinerary.days[_validMapDayIndex ?? _selectedDayIndex];

  @override
  void initState() {
    super.initState();
    _weatherAdvisoryService = WeatherAdvisoryService(
      apiKey: const String.fromEnvironment('CWA_API_KEY'),
    );
    _countyResolver = TaiwanCountyResolver.load();
    _itinerary = widget.itinerary;
    _constraints = _constraintsFromItinerary(_itinerary);
    _travelModeOverrides = Map.of(_itinerary.travelModeOverrides);
    _tripTracker.updates.listen(_handleTrackingUpdate);
  }

  @override
  void didUpdateWidget(covariant ItineraryResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itinerary, widget.itinerary)) {
      _itinerary = widget.itinerary;
      _mapDayIndex = _validMapDayIndex;
      _constraints = _constraintsFromItinerary(_itinerary);
      _travelModeOverrides = Map.of(_itinerary.travelModeOverrides);
      _tripTracker.updateItinerary(_itinerary);
      _selectedDayIndex = min(
        _selectedDayIndex,
        max(0, _itinerary.days.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _tripTracker.dispose();
    _weatherAdvisoryService.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _itinerary.request.title.trim().isEmpty
              ? '行程規劃結果'
              : _itinerary.request.title,
        ),
        actions: [
          SaveItineraryButton(
            itinerary: _itinerary,
            enabled:
                _itinerary.days.isNotEmpty &&
                !_isRecalculating &&
                _pendingPlaces.isEmpty,
          ),
          TextButton.icon(
            onPressed: _itinerary.days.isEmpty
                ? null
                : () => setState(() => _isMapVisible = !_isMapVisible),
            icon: Icon(_isMapVisible ? Icons.map_outlined : Icons.map),
            label: Text(_isMapVisible ? '隱藏地圖' : '顯示地圖'),
          ),
          TextButton.icon(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(
              _isTracking
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
            ),
            label: Text(_isTracking ? '停止追蹤' : '開始行程'),
          ),
          IconButton(
            tooltip: '編輯行程',
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '匯出行程',
            onPressed: widget.onExport,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: _itinerary.days.isEmpty
          ? const Center(child: Text('目前沒有可顯示的行程。'))
          : LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  _buildToolbar(),
                  if (_pendingPlaces.isNotEmpty) _buildPendingArea(),
                  if (_itinerary.warnings.isNotEmpty) _buildWarnings(),
                  if (_isMapVisible) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18),
                          const SizedBox(width: 8),
                          const Text('地圖日期：'),
                          Expanded(
                            child: DropdownButton<int>(
                              key: const ValueKey('map-day-selector'),
                              isExpanded: true,
                              value: _validMapDayIndex ?? -1,
                              items: [
                                DropdownMenuItem(
                                  value: -1,
                                  child: Text(
                                    '跟隨行程（Day ${_itinerary.days[_selectedDayIndex].day}）',
                                  ),
                                ),
                                for (
                                  var index = 0;
                                  index < _itinerary.days.length;
                                  index++
                                )
                                  DropdownMenuItem(
                                    value: index,
                                    child: Text(
                                      'Day ${_itinerary.days[index].day} · ${_itinerary.days[index].date.month}/${_itinerary.days[index].date.day}',
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(() {
                                _mapDayIndex = value == -1 ? null : value;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: constraints.maxHeight * _mapHeightRatio,
                      child: TripMapPanel(
                        day: _mapDay,
                        currentLocation: _currentLocation,
                        trackedRoute: _trackedRoute,
                      ),
                    ),
                    _buildResizeHandle(constraints.maxHeight),
                  ],
                  Expanded(child: _buildTimetable()),
                ],
              ),
            ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _isRecalculating ? null : _addPlace,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('新增景點'),
              ),
              const SizedBox(width: 12),
              if (_isTracking) ...[
                const Icon(Icons.gps_fixed, size: 18),
                const SizedBox(width: 6),
                const Text('GPS 追蹤中'),
                const SizedBox(width: 12),
              ],
              const Expanded(
                child: Text(
                  '長按景點後拖到新的 Day 與時間；鎖定時段不接受放置。',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isRecalculating) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 8),
                const Text('正在重排…'),
              ],
            ],
          ),
          if (kDebugMode)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _showDebugDelayDialog,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('模擬延誤'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPendingArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '暫定區｜請把新增的景點拖到課表',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingPlaces.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final place = _pendingPlaces[index];
                final card = _PendingCard(
                  place: place,
                  onDelete: () => setState(
                    () => _pendingPlaces.removeWhere(
                      (item) => item.id == place.id,
                    ),
                  ),
                );
                return MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Draggable<_DragData>(
                    data: _DragData(place),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      child: SizedBox(width: 230, child: card),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: card),
                    child: card,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetable() {
    final startHour = _startHour;
    final endHour = _endHour;
    final height = (endHour - startHour) * _hourHeight;
    final width = _timeWidth + _itinerary.days.length * _dayWidth;
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(
                    height: height,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimeAxis(startHour, endHour),
                        for (var i = 0; i < _itinerary.days.length; i++)
                          _buildDayColumn(i, startHour, endHour),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(
            width: _timeWidth,
            child: Center(child: Text('時間')),
          ),
          for (var i = 0; i < _itinerary.days.length; i++)
            InkWell(
              onTap: () => setState(() => _selectedDayIndex = i),
              child: Container(
                width: _dayWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == _selectedDayIndex
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Day ${_itinerary.days[i].day}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_formatDate(_itinerary.days[i].date)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeAxis(int startHour, int endHour) {
    return SizedBox(
      width: _timeWidth,
      child: Column(
        children: [
          for (var hour = startHour; hour < endHour; hour++)
            Container(
              height: _hourHeight,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Text('${hour.toString().padLeft(2, '0')}:00'),
            ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(int dayIndex, int startHour, int endHour) {
    final day = _itinerary.days[dayIndex];
    return SizedBox(
      width: _dayWidth,
      height: (endHour - startHour) * _hourHeight,
      child: Stack(
        children: [
          for (var hour = startHour; hour < endHour; hour++)
            Positioned(
              left: 0,
              right: 0,
              top: (hour - startHour) * _hourHeight,
              height: _hourHeight,
              child: _buildDropCell(day, hour),
            ),
          for (var i = 0; i < day.visits.length; i++)
            _buildVisit(day, day.visits[i], startHour),
        ],
      ),
    );
  }

  Widget _buildDropCell(RouteDay day, int hour) {
    final startMinutes = hour * 60;
    final isPastTime = _isPastDropTime(day: day, startMinutes: startMinutes);

    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (details) =>
          !_isRecalculating &&
          !isPastTime &&
          !_overlapsLockedVisit(
            place: details.data.place,
            day: day.day,
            startMinutes: startMinutes,
            ignoredPlaceId: details.data.place.id,
          ),
      onAcceptWithDetails: (details) => _dropPlace(
        place: details.data.place,
        day: day.day,
        startMinutes: startMinutes,
      ),
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rejected.isNotEmpty
                ? Theme.of(context).colorScheme.errorContainer
                : candidate.isNotEmpty
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: rejected.isNotEmpty
              ? Text(isPastTime ? '此時間已經過去' : '此時段已鎖定')
              : candidate.isNotEmpty
              ? Text(
                  '放到 Day ${day.day} '
                  '${_formatMinutes(startMinutes)}',
                )
              : null,
        );
      },
    );
  }

  bool _isPastDropTime({required RouteDay day, required int startMinutes}) {
    final dropDateTime = DateTime(
      day.date.year,
      day.date.month,
      day.date.day,
    ).add(Duration(minutes: startMinutes));

    final now = DateTime.now();

    // 與排程起始時間規則一致：最早只能放在現在的下一分鐘。
    final minimumDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));

    return dropDateTime.isBefore(minimumDateTime);
  }

  Widget _buildVisit(RouteDay day, RouteVisit visit, int startHour) {
    final travelLegIndex = day.travelLegs.indexWhere(
      (leg) => leg.destination.id == visit.occurrenceId,
    );
    final top = (visit.startMinutes - startHour * 60) / 60 * _hourHeight;
    final height = max(28.0, visit.stayMinutes / 60 * _hourHeight - 4);
    final card = _VisitCard(
      visit: visit,
      onTap: _isRecalculating ? null : () => _editVisitPreferences(visit),
      onShowTravel: travelLegIndex >= 0
          ? () => _showTravelLeg(day, travelLegIndex)
          : null,
      onDelete: _isRecalculating ? null : () => _deletePlace(visit.place),
    );
    return Positioned(
      left: 6,
      right: 6,
      top: max(0.0, top),
      height: height,
      child:
          visit.locked ||
              visit.place.type == PlaceType.accommodation ||
              _isRecalculating
          ? card
          : MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Draggable<_DragData>(
                data: _DragData(visit.place),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  child: SizedBox(
                    width: _dayWidth - 20,
                    height: min(height, 120.0),
                    child: card,
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: card),
                child: card,
              ),
            ),
    );
  }

  Widget _buildWarnings() {
    return MaterialBanner(
      content: Text(_itinerary.warnings.join('\n')),
      leading: const Icon(Icons.info_outline),
      actions: const [SizedBox.shrink()],
    );
  }

  Widget _buildResizeHandle(double availableHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => setState(() {
        _mapHeightRatio = (_mapHeightRatio + details.delta.dy / availableHeight)
            .clamp(0.2, 0.65)
            .toDouble();
      }),
      child: Container(
        height: 22,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Container(
          width: 52,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Future<void> _startTracking() async {
    _isStartingWeatherFlow = true;
    _hasReportedWeatherError = false;
    await _showInitialWeatherOverview();
    if (!mounted) return;
    final started = await _tripTracker.start(_itinerary);
    if (!mounted) return;
    if (!started) {
      _isStartingWeatherFlow = false;
      _showMessage('無法取得 GPS 位置，請確認已開啟定位服務並允許位置權限。');
      return;
    }
    setState(() {
      _isTracking = true;
      _isMapVisible = true;
    });
    _isStartingWeatherFlow = false;
    final currentLocation = _currentLocation;
    if (currentLocation != null) {
      final weather = await _checkWeatherAtCurrentLocation(currentLocation);
      if (weather != null && mounted) {
        await _showWeatherAdvisory(weather.advisories);
      } else if (weather == null) {
        _reportWeatherErrorOnce();
      }
    }
    _showMessage('已開始 GPS 行程追蹤；若明顯延誤，系統會更新今天剩餘行程。');
  }

  Future<void> _stopTracking() async {
    await _tripTracker.stop();
    if (mounted) setState(() => _isTracking = false);
  }

  Future<void> _showWeatherOverview(CwaForecast forecast) {
    String value(double? number, String unit) => number == null
        ? '暫無資料'
        : '${number.toStringAsFixed(number % 1 == 0 ? 0 : 1)}$unit';
    final city = forecast.cityName ?? '';
    final district = forecast.locationName ?? '';
    final displayLocation = district.startsWith(city)
        ? district
        : '$city$district';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.wb_cloudy_outlined),
        title: Text(
          '${displayLocation.isEmpty ? '行程地點' : displayLocation}天氣綜覽',
        ),
        content: SizedBox(
          width: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forecast.weatherDescription ?? '暫無天氣預報綜合描述',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _weatherOverviewRow(
                Icons.umbrella_outlined,
                '3 小時降雨機率',
                value(forecast.precipitationProbability, '%'),
              ),
              _weatherOverviewRow(
                Icons.thermostat_outlined,
                '最高溫度',
                value(forecast.maximumTemperature, '°C'),
              ),
              _weatherOverviewRow(
                Icons.wb_sunny_outlined,
                '紫外線指數',
                value(forecast.uvIndex, ''),
              ),
              _weatherOverviewRow(
                Icons.ac_unit_outlined,
                '最低溫度',
                value(forecast.minimumTemperature, '°C'),
              ),
              const SizedBox(height: 12),
              Text(
                '資料來源：CWA /v1/rest/datastore/F-D0047-093',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('查看行程'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInitialWeatherOverview() async {
    final now = DateTime.now();
    final day = _itinerary.days
        .where(
          (item) =>
              item.date.year == now.year &&
              item.date.month == now.month &&
              item.date.day == now.day,
        )
        .firstOrNull;
    final visits = day?.visits ?? const <RouteVisit>[];
    final visit =
        visits
            .where((item) => item.place.type == PlaceType.attraction)
            .firstOrNull ??
        visits.firstOrNull;
    if (visit == null) {
      _showMessage('今天沒有可用來查詢天氣的景點。');
      return;
    }

    final names = _weatherLocationNames(visit.place);
    final forecast = await _weatherAdvisoryService.overviewForPlace(
      districtName: names.district,
      cityName: names.city,
      placePosition: LocationPoint(
        latitude: visit.place.latitude,
        longitude: visit.place.longitude,
      ),
      now: now,
    );
    if (!mounted) return;
    if (forecast == null) {
      _reportWeatherErrorOnce();
      return;
    }
    await _showWeatherOverview(forecast);
  }

  ({String? district, String? city}) _weatherLocationNames(Place place) {
    final address = place.address.trim();
    final databaseCity = place.county.trim().replaceAll('台', '臺');
    final databaseDistrict = place.district.trim().replaceAll('台', '臺');
    final cityMatch = RegExp(
      r'(臺北市|台北市|新北市|桃園市|臺中市|台中市|臺南市|台南市|高雄市|基隆市|新竹市|嘉義市|新竹縣|苗栗縣|彰化縣|南投縣|雲林縣|嘉義縣|屏東縣|宜蘭縣|花蓮縣|臺東縣|台東縣|澎湖縣|金門縣|連江縣)',
    ).firstMatch(address);
    final city = databaseCity.isNotEmpty
        ? databaseCity
        : (cityMatch?.group(1) ?? '').replaceAll('台', '臺');
    final afterCity = cityMatch == null
        ? address
        : address.substring(cityMatch.end);
    final district = databaseDistrict.isNotEmpty
        ? databaseDistrict
        : RegExp(
            r'^([\u4e00-\u9fff]{1,5}(?:區|鄉|鎮|市))',
          ).firstMatch(afterCity)?.group(1);
    return (
      district: district?.replaceAll('台', '臺'),
      city: city.isEmpty ? null : city,
    );
  }

  void _reportWeatherErrorOnce() {
    if (_hasReportedWeatherError || !mounted) return;
    _hasReportedWeatherError = true;
    _showMessage(_weatherAdvisoryService.lastError ?? '目前無法取得 CWA 天氣資料。');
  }

  Future<WeatherCheckResult?> _checkWeatherAtCurrentLocation(
    LocationPoint location,
  ) async {
    final resolver = await _countyResolver;
    final city = resolver.resolve(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    return _weatherAdvisoryService.check(location, cityName: city);
  }

  Widget _weatherOverviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showDebugDelayDialog() async {
    if (!kDebugMode) return;
    var scenario = DebugDelayScenario.stayTooLong;
    var delayMinutes = 30;
    final shouldSimulate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('模擬延誤'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<DebugDelayScenario>(
                title: const Text('在目前景點停留太久'),
                value: DebugDelayScenario.stayTooLong,
                groupValue: scenario,
                onChanged: (value) => setDialogState(() => scenario = value!),
              ),
              RadioListTile<DebugDelayScenario>(
                title: const Text('距離下一個景點太遠'),
                value: DebugDelayScenario.farFromNextStop,
                groupValue: scenario,
                onChanged: (value) => setDialogState(() => scenario = value!),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('模擬延誤時間'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final minutes in [15, 30, 60])
                    ChoiceChip(
                      label: Text('$minutes 分鐘'),
                      selected: delayMinutes == minutes,
                      onSelected: (_) =>
                          setDialogState(() => delayMinutes = minutes),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('執行模擬'),
            ),
          ],
        ),
      ),
    );
    if (shouldSimulate != true || !mounted) return;

    final hasToday = _itinerary.days.any(
      (day) =>
          day.date.year == DateTime.now().year &&
          day.date.month == DateTime.now().month &&
          day.date.day == DateTime.now().day,
    );
    if (!hasToday) {
      _showMessage('請先建立包含今天的行程，才能模擬延誤。');
      return;
    }
    setState(() => _isMapVisible = true);
    _tripTracker.simulateDelay(
      itinerary: _itinerary,
      scenario: scenario,
      delayMinutes: delayMinutes,
    );
  }

  Future<void> _showWeatherAdvisory(List<WeatherAdvisory> advisories) async {
    if (!mounted || advisories.isEmpty) return;
    final shouldOfferIndoor = WeatherAdvisory.shouldOfferIndoorAlternative(
      advisories,
    );
    final advice = advisories.map((advisory) => advisory.body).join('\n\n');
    final wantsIndoorAlternatives = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          shouldOfferIndoor
              ? Icons.home_work_outlined
              : Icons.health_and_safety_outlined,
        ),
        title: Text(shouldOfferIndoor ? '天氣可能影響戶外行程' : '天氣提醒'),
        content: Text(
          shouldOfferIndoor ? '$advice\n\n要請 AI 推薦室內替代行程嗎？' : advice,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(shouldOfferIndoor ? '維持目前行程' : '知道了'),
          ),
          if (shouldOfferIndoor)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('查看室內建議'),
            ),
        ],
      ),
    );
    if (!shouldOfferIndoor || wantsIndoorAlternatives != true || !mounted)
      return;
    final request = WeatherIndoorItineraryRequest(
      advisories: advisories,
      requestedAt: DateTime.now(),
    );
    final handler = widget.onRequestIndoorItineraryAlternatives;
    if (handler == null) {
      _showMessage('已建立室內行程推薦請求（等待串接 AI 推薦服務）。');
      return;
    }
    try {
      await handler(request);
      if (mounted) _showMessage('已送出室內行程推薦請求。');
    } catch (_) {
      if (mounted) _showMessage('室內行程推薦暫時無法使用，請稍後再試。');
    }
  }

  Future<void> _handleTrackingUpdate(TripTrackingUpdate update) async {
    if (!mounted) return;
    setState(() {
      _currentLocation = update.location;
      _trackedRoute = update.route;
    });
    if (_isStartingWeatherFlow) return;
    final weather = await _checkWeatherAtCurrentLocation(update.location);
    if (weather != null && mounted) {
      await _showWeatherAdvisory(weather.advisories);
    } else if (weather == null && _weatherAdvisoryService.lastError != null) {
      _reportWeatherErrorOnce();
    }
    final alert = update.delayAlert;
    if (alert == null || _isLiveReplanning) return;

    final now = update.observedAt;
    final dayIndex = _itinerary.days.indexWhere(
      (day) =>
          day.date.year == now.year &&
          day.date.month == now.month &&
          day.date.day == now.day,
    );
    if (dayIndex < 0) return;

    _isLiveReplanning = true;
    try {
      final revisedDay = _liveDayReplanner.replan(
        day: _itinerary.days[dayIndex],
        currentLocation: update.location,
        now: now,
      );
      final revisedDays = List.of(_itinerary.days)..[dayIndex] = revisedDay;
      final revised = RouteItinerary(
        request: _itinerary.request,
        origin: _itinerary.origin,
        days: revisedDays,
        generatedAt: now,
        warnings: _itinerary.warnings,
        inputs: _itinerary.inputs,
        travelModeOverrides: _itinerary.travelModeOverrides,
      );
      _tripTracker.updateItinerary(revised);
      if (!mounted) return;
      setState(() {
        _itinerary = revised;
        _selectedDayIndex = dayIndex;
        _mapDayIndex = dayIndex;
      });
      await _notificationService.showScheduleAdjusted(
        lateMinutes: alert.lateMinutes,
        nextStopName: alert.nextStopName,
      );
      if (mounted) {
        _showMessage('已依目前位置更新 Day ${revisedDay.day} 的後續行程。');
      }
    } catch (_) {
      if (mounted) _showMessage('偵測到延誤，但暫時無法重新安排今日行程。');
    } finally {
      _isLiveReplanning = false;
    }
  }

  Future<void> _addPlace() async {
    if (widget.onAddPlace == null) {
      _showMessage('請先在上一層頁面接上 onAddPlace。');
      return;
    }
    final selectedPlaceIds = {
      for (final constraint in _constraints) constraint.place.id,
      for (final place in _pendingPlaces) place.id,
    };
    final places = await widget.onAddPlace!(context, selectedPlaceIds);
    if (!mounted || places.isEmpty) return;

    final newPlaces = <Place>[];
    for (final place in places) {
      if (selectedPlaceIds.add(place.id)) {
        newPlaces.add(place);
      }
    }
    if (newPlaces.isEmpty) {
      _showMessage('選擇的景點已經在行程或暫定區中。');
      return;
    }
    setState(() => _pendingPlaces.addAll(newPlaces));
  }

  Future<void> _dropPlace({
    required Place place,
    required int day,
    required int startMinutes,
  }) async {
    if (_isRecalculating) return;
    final backup = _copyConstraints(_constraints);
    final pendingBackup = List<Place>.of(_pendingPlaces);
    final index = _constraints.indexWhere((item) => item.place.id == place.id);
    final preferences = index < 0
        ? const VisitPreferences()
        : _constraints[index].preferences;
    final changed = TripPlaceConstraint(
      place: place,
      day: preferences.hotelStay?.checkInDay ?? day,
      startMinutes: startMinutes,
      locked: true,
      preferences: preferences,
    );
    if (index < 0) {
      _constraints.add(changed);
    } else {
      _constraints[index] = changed;
    }
    _pendingPlaces.removeWhere((item) => item.id == place.id);
    if (!await _recalculate() && mounted) {
      setState(() {
        _constraints = backup;
        _pendingPlaces
          ..clear()
          ..addAll(pendingBackup);
      });
    }
  }

  Future<void> _deletePlace(Place place) async {
    final backup = _copyConstraints(_constraints);
    setState(
      () => _constraints.removeWhere((item) => item.place.id == place.id),
    );
    if (!await _recalculate() && mounted) {
      setState(() => _constraints = backup);
    }
  }

  Future<void> _editVisitPreferences(RouteVisit visit) async {
    final index = _constraints.indexWhere(
      (item) => item.place.id == visit.place.id,
    );
    if (index < 0) return;
    final constraint = _constraints[index];
    final preferences = await showVisitPreferencesDialog(
      context: context,
      place: visit.place,
      request: _itinerary.request,
      initial: constraint.preferences,
      day: constraint.day,
      suggestedMealType: constraint.preferences.mealType == MealType.unspecified
          ? visit.mealType
          : null,
      information: visit.information,
    );
    if (!mounted || preferences == null) return;
    final backup = _copyConstraints(_constraints);
    constraint.preferences = preferences;
    if (preferences.hotelStay != null) {
      constraint.day = preferences.hotelStay!.checkInDay;
    }
    if (!await _recalculate() && mounted) {
      setState(() => _constraints = backup);
    }
  }

  Future<bool> _recalculate() async {
    if (widget.onRecalculate == null) {
      _showMessage('請先在上一層頁面接上 onRecalculate。');
      return false;
    }
    setState(() => _isRecalculating = true);
    try {
      final result = await widget.onRecalculate!(
        _copyConstraints(_constraints),
        Map.of(_travelModeOverrides),
        _itinerary,
      );
      if (!mounted) return false;
      setState(() {
        _itinerary = result;
        _mapDayIndex = _validMapDayIndex;
        _constraints = _constraintsFromItinerary(result);
        _travelModeOverrides = Map.of(result.travelModeOverrides);
        _selectedDayIndex = min(
          _selectedDayIndex,
          max(0, result.days.length - 1),
        );
      });
      _tripTracker.updateItinerary(result);
      return true;
    } catch (error) {
      if (mounted) _showMessage('重新安排行程失敗：$error');
      return false;
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  void _showTravelLeg(RouteDay day, int index) {
    final leg = day.travelLegs[index];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SingleChildScrollView(
            child: TravelLegCard(
              leg: leg,
              onTravelModeChanged: (travelMode) {
                Navigator.of(context).pop();
                _changeTravelLegMode(day.day, leg, travelMode);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeTravelLegMode(
    int day,
    TravelLeg leg,
    RouteTravelMode travelMode,
  ) async {
    final key = routeLegKey(
      day: day,
      originId: leg.origin.id,
      destinationId: leg.destination.id,
    );
    final backup = Map<RouteLegKey, RouteTravelMode>.of(_travelModeOverrides);
    setState(() {
      if (travelMode == RouteTravelMode.transit) {
        _travelModeOverrides.remove(key);
      } else {
        _travelModeOverrides[key] = travelMode;
      }
    });
    if (!await _recalculate() && mounted) {
      setState(() => _travelModeOverrides = backup);
    }
  }

  bool _overlapsLockedVisit({
    required Place place,
    required int day,
    required int startMinutes,
    required String ignoredPlaceId,
  }) {
    final matching = _constraints.where((item) => item.place.id == place.id);
    final duration = matching.isEmpty
        ? const VisitPreferences().durationFor(place)
        : matching.first.stayMinutes;
    final endMinutes = startMinutes + duration;
    for (final item in _constraints) {
      if (!item.locked ||
          item.day != day ||
          item.place.id == ignoredPlaceId ||
          item.startMinutes == null) {
        continue;
      }
      final lockedStart = item.startMinutes!;
      final lockedEnd = lockedStart + item.stayMinutes;
      if (startMinutes < lockedEnd && endMinutes > lockedStart) return true;
    }
    return false;
  }

  List<TripPlaceConstraint> _constraintsFromItinerary(
    RouteItinerary itinerary,
  ) {
    if (itinerary.inputs.isNotEmpty) {
      return [
        for (final input in itinerary.inputs)
          TripPlaceConstraint(
            place: input.place,
            day: input.day,
            startMinutes: input.startMinutes,
            locked: input.locked,
            preferences: input.preferences,
          ),
      ];
    }
    return [
      for (final day in itinerary.days)
        for (final visit in day.visits)
          TripPlaceConstraint(
            place: visit.place,
            day: visit.locked ? day.day : null,
            startMinutes: visit.locked
                ? visit.requestedStartMinutes ?? visit.startMinutes
                : null,
            locked: visit.locked,
            preferences: visit.preferences,
          ),
    ];
  }

  List<TripPlaceConstraint> _copyConstraints(List<TripPlaceConstraint> values) {
    return values
        .map(
          (item) => TripPlaceConstraint(
            place: item.place,
            day: item.day,
            startMinutes: item.startMinutes,
            locked: item.locked,
            preferences: item.preferences,
          ),
        )
        .toList();
  }

  int get _startHour {
    return 0;
  }

  int get _endHour {
    final ends = [
      for (final day in _itinerary.days)
        for (final visit in day.visits) visit.endMinutes,
    ];
    return ends.isEmpty ? 24 : max(24, (ends.reduce(max) / 60).ceil());
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:'
        '${(normalized % 60).toString().padLeft(2, '0')}';
  }

  static String _formatDate(DateTime date) => '${date.month}/${date.day}';
}

class _DragData {
  final Place place;
  const _DragData(this.place);
}

class _PendingCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onDelete;
  const _PendingCard({required this.place, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: 230,
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.drag_indicator),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '移除',
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final RouteVisit visit;
  final VoidCallback? onTap;
  final VoidCallback? onShowTravel;
  final VoidCallback? onDelete;

  const _VisitCard({
    required this.visit,
    this.onTap,
    this.onShowTravel,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expandedCard = Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: visit.locked ? colors.primaryContainer : colors.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                visit.locked ? Icons.lock_outline : Icons.drag_indicator,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_formatMinutes(visit.startMinutes)}–'
                      '${_formatMinutes(visit.endMinutes)}・點擊設定／資訊',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (onShowTravel != null)
                      TextButton.icon(
                        onPressed: onShowTravel,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.directions_transit, size: 17),
                        label: const Text('交通方式'),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: visit.place.type == PlaceType.accommodation
                    ? '移除整筆跨日住宿'
                    : '移除項目',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= 110) return expandedCard;
        return Tooltip(
          message:
              '${visit.label}\n${_formatMinutes(visit.startMinutes)}–${_formatMinutes(visit.endMinutes)}\n點擊設定／資訊',
          child: Card(
            margin: EdgeInsets.zero,
            color: visit.locked
                ? colors.primaryContainer
                : colors.secondaryContainer,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_formatMinutes(visit.startMinutes)} ${visit.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onShowTravel != null)
                      IconButton(
                        tooltip: '交通方式',
                        onPressed: onShowTravel,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.directions_transit, size: 18),
                      ),
                    IconButton(
                      tooltip: visit.place.type == PlaceType.accommodation
                          ? '移除整筆跨日住宿'
                          : '移除項目',
                      onPressed: onDelete,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:'
        '${(normalized % 60).toString().padLeft(2, '0')}';
  }
}
