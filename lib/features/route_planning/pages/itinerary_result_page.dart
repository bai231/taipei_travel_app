import 'dart:math';
import 'dart:async';
import '../models/compact_day_axis.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/trip/android_layout.dart';
import '../widgets/android_day_itinerary.dart';

import '../../../models/place.dart';
import '../../../models/tdx_route.dart';
import '../../../models/trip_place_constraint.dart';
import '../../../models/visit_preferences.dart';
import '../../../services/live_itinerary_tracking_service.dart';
import '../../../services/live_itinerary_alternative_planner.dart';
import '../../../services/google_route_planning_service.dart';
import '../../../services/location_service.dart';
import '../../../services/taiwan_county_resolver.dart';
import '../../../services/weather_advisory_service.dart';
import '../../../services/transit_alternative_service.dart';
import '../../../services/transit_realtime_monitor.dart';
import '../services/active_guardian_session.dart';

import '../../../widgets/trip/visit_preferences_dialog.dart';
import '../../../widgets/trip/save_itinerary_button.dart';
import '../debug/guardian_debug_console.dart';
import 'itinerary_result_dependencies.dart';
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

typedef _ComparisonEntry = ({
  int startMinutes,
  String title,
  String? subtitle,
  String? details,
  IconData? icon,
});

class ItineraryResultPage extends StatefulWidget {
  final RouteItinerary itinerary;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final AddItineraryPlaces? onAddPlace;
  final RecalculateItinerary? onRecalculate;
  final ItineraryResultDependencies? dependencies;

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
    this.dependencies,
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  double _timetableZoom = 1;
  double get _dayWidth => usesAndroidTripLayout && !_androidOverview
      ? max(160, MediaQuery.sizeOf(context).width - _timeWidth)
      : 280 * _timetableZoom;
  static const _timeWidth = 64.0;
  double get _hourHeight => 92 * _timetableZoom;
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();
  final List<Place> _pendingPlaces = [];
  late final WeatherAdvisoryService _weatherAdvisoryService;
  late final Future<TaiwanCountyResolver> _countyResolver;
  late final ItineraryResultDependencies _dependencies;
  late final LiveItineraryTrackingService _tripTracker;
  StreamSubscription<TripTrackingUpdate>? _trackingUpdatesSubscription;
  ActiveGuardianSession? _guardianSession;
  late final ForegroundTransitGuardian _transitGuardian;
  late final TransitAlternativeService _transitAlternativeService;
  late final LiveItineraryAlternativePlanner _alternativePlanner;

  late RouteItinerary _itinerary;
  late List<TripPlaceConstraint> _constraints;
  late Map<RouteLegKey, RouteTravelMode> _travelModeOverrides;
  int _selectedDayIndex = 0;
  int? _mapDayIndex;
  bool _isMapVisible = false;
  bool _androidOverview = false;
  bool _expandAllHours = false;
  final Set<int> _expandedHours = {};
  Timer? _gapHoverTimer;
  bool _isRecalculating = false;
  bool _isTracking = false;
  bool _hasReportedWeatherError = false;
  bool _isStartingTracking = false;
  bool _isAlternativePromptOpen = false;
  bool _isEvaluatingTrackingUpdate = false;
  bool _realtimeWarningShown = false;
  final Map<String, DateTime> _lastTransitRiskPromptAt = {};
  final Map<int, int> _confirmedCompletedCounts = {};

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
    _countyResolver = TaiwanCountyResolver.load();
    _mapHeightRatio = usesAndroidTripLayout ? 0.26 : 0.34;
    final existingSession = ActiveGuardianSession.active;
    final resumeSession =
        existingSession != null &&
        identical(existingSession.itinerary, widget.itinerary);
    _guardianSession = resumeSession ? existingSession : null;

    _itinerary = widget.itinerary;
    _constraints = _constraintsFromItinerary(_itinerary);
    _travelModeOverrides = Map.of(_itinerary.travelModeOverrides);
    _dependencies =
        _guardianSession?.dependencies ??
        widget.dependencies ??
        ItineraryResultDependencies.production();
    _weatherAdvisoryService =
        _dependencies.productionWeatherService ??
        WeatherAdvisoryService(
          apiKey: const String.fromEnvironment('CWA_API_KEY'),
        );
    _tripTracker =
        _guardianSession?.tracker ??
        LiveItineraryTrackingService(
          locationGateway: _dependencies.locationGateway,
          now: _dependencies.now,
        );
    _transitGuardian = ForegroundTransitGuardian(
      monitor: TransitRealtimeMonitor(gateway: _dependencies.realtimeGateway),
      minimumCheckInterval: const Duration(minutes: 2),
    );
    _transitAlternativeService = TransitAlternativeService(
      routingGateway: _dependencies.routingGateway,
    );
    _alternativePlanner = LiveItineraryAlternativePlanner(
      transit: _dependencies.routingGateway,
      google:
          _dependencies.googleRoutingGateway ??
          const GoogleRoutePlanningService(),
    );
    _trackingUpdatesSubscription = _tripTracker.updates.listen(
      _handleTrackingUpdate,
    );
    if (_guardianSession != null) {
      _isTracking = true;
      _guardianSession!.attachPage(onResume: _resumePendingGuardianRisk);
      final latest = _guardianSession!.latestUpdate;
      if (latest != null) {
        _currentLocation = latest.location;
        _trackedRoute = latest.route;
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _resumePendingGuardianRisk(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ItineraryResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itinerary, widget.itinerary)) {
      _itinerary = widget.itinerary;
      _mapDayIndex = _validMapDayIndex;
      _constraints = _constraintsFromItinerary(_itinerary);
      _travelModeOverrides = Map.of(_itinerary.travelModeOverrides);
      _updateTrackedItinerary(_itinerary);
      _selectedDayIndex = min(
        _selectedDayIndex,
        max(0, _itinerary.days.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _gapHoverTimer?.cancel();
    _trackingUpdatesSubscription?.cancel();
    if (_guardianSession != null &&
        identical(ActiveGuardianSession.active, _guardianSession)) {
      _guardianSession!.detachPage();
    } else {
      _tripTracker.dispose();
      _dependencies.weatherGateway.dispose();
      _dependencies.disposeRealtimeGateway?.call();
    }
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
          if (usesAndroidTripLayout)
            IconButton(
              tooltip: _isStartingTracking
                  ? '正在取得定位'
                  : (_isTracking ? '停止追蹤' : '開始行程'),
              onPressed: _isStartingTracking
                  ? null
                  : (_isTracking ? _stopTracking : _startTracking),
              icon: Icon(
                _isTracking
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
              ),
            )
          else
            TextButton.icon(
              onPressed: _isStartingTracking
                  ? null
                  : (_isTracking ? _stopTracking : _startTracking),
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
          if (!usesAndroidTripLayout || widget.onExport != null)
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
                  if (kDebugMode &&
                      _dependencies.debugController != null &&
                      !usesAndroidTripLayout)
                    _buildGuardianDebugEntry(),
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
                  Expanded(
                    child: usesAndroidTripLayout && !_androidOverview
                        ? AndroidDayItinerary(
                            timetable: _buildCompactDay(),
                            days: _itinerary.days,
                            selectedDay: _selectedDayIndex,
                            onDayChanged: (index) => setState(() {
                              _gapHoverTimer?.cancel();
                              _expandedHours.clear();
                              _selectedDayIndex = index;
                            }),
                            onEdit: _isRecalculating
                                ? null
                                : _editVisitPreferences,
                            onDelete: _isRecalculating
                                ? null
                                : (visit) => _deletePlace(visit.place),
                            onTravel: (visit) {
                              final day = _itinerary.days[_selectedDayIndex];
                              final index = day.travelLegs.indexWhere(
                                (leg) =>
                                    leg.destination.id == visit.occurrenceId,
                              );
                              if (index >= 0) _showTravelLeg(day, index);
                            },
                          )
                        : usesAndroidTripLayout
                        ? _buildCompactOverview()
                        : _buildTimetable(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToolbar() {
    if (usesAndroidTripLayout) return _buildAndroidToolbar();
    final zoomControls = <Widget>[
      IconButton(
        tooltip: '縮小行程表',
        onPressed: _timetableZoom <= 0.6 ? null : () => _setZoom(-0.2),
        icon: const Icon(Icons.zoom_out),
      ),
      Text('${(_timetableZoom * 100).round()}%'),
      IconButton(
        tooltip: '放大行程表',
        onPressed: _timetableZoom >= 1.8 ? null : () => _setZoom(0.2),
        icon: const Icon(Icons.zoom_in),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _isRecalculating ? null : _addPlace,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('新增景點'),
          ),
          if (usesAndroidTripLayout)
            TextButton(
              onPressed: () =>
                  setState(() => _androidOverview = !_androidOverview),
              child: Text(_androidOverview ? '單日課表' : '多日總覽'),
            ),
          const SizedBox(width: 12),
          if (_isTracking) ...[
            const Icon(Icons.gps_fixed, size: 18),
            const SizedBox(width: 6),
            const Text('GPS 追蹤中'),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () async {
                final now = _dependencies.now();
                final index = _itinerary.days.indexWhere(
                  (day) =>
                      day.date.year == now.year &&
                      day.date.month == now.month &&
                      day.date.day == now.day,
                );
                if (index >= 0) {
                  await _confirmCompletedCount(_itinerary.days[index]);
                }
              },
              icon: const Icon(Icons.checklist),
              label: const Text('確認進度'),
            ),
            TextButton.icon(
              onPressed: _isAlternativePromptOpen
                  ? null
                  : _requestRemainingAlternative,
              icon: const Icon(Icons.alt_route),
              label: const Text('重排剩餘行程'),
            ),
          ],
          if (!usesAndroidTripLayout)
            const Text('長按景點後拖到新的 Day 與時間；鎖定時段不接受放置。'),
          if (usesAndroidTripLayout && _androidOverview)
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: zoomControls,
                ),
              ),
            ),
          if (!usesAndroidTripLayout) ...zoomControls,
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
    );
  }

  Widget _buildAndroidToolbar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        FilledButton.icon(
          onPressed: _isRecalculating ? null : _addPlace,
          icon: const Icon(Icons.add_location_alt_outlined, size: 18),
          label: const Text('新增'),
        ),
        IconButton(
          tooltip: _androidOverview ? '單日課表' : '多日總覽',
          onPressed: () => setState(() => _androidOverview = !_androidOverview),
          icon: Icon(
            _androidOverview
                ? Icons.view_day_outlined
                : Icons.view_week_outlined,
          ),
        ),
        const Spacer(),
        if (_isRecalculating)
          const SizedBox(
            width: 32,
            height: 24,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_isTracking)
          IconButton(
            tooltip: 'GPS 追蹤中',
            onPressed: _showTrackingStatus,
            color: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.gps_fixed),
          ),
        if (kDebugMode && _dependencies.debugController != null)
          IconButton(
            tooltip: '保母測試控制台',
            onPressed: _showGuardianDebugConsole,
            color: _dependencies.debugController!.enabled
                ? Colors.deepOrange
                : null,
            icon: Icon(
              _dependencies.debugController!.enabled
                  ? Icons.science
                  : Icons.science_outlined,
            ),
          ),
        PopupMenuButton<String>(
          tooltip: '更多行程操作',
          onSelected: _handleAndroidToolbarAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'hours',
              child: Text(_expandAllHours ? '壓縮頭尾空白' : '展開全部時段'),
            ),
            if (_androidOverview) ...[
              PopupMenuItem(
                value: 'zoom-out',
                enabled: _timetableZoom > 0.6,
                child: Text('縮小行程表 · ${(_timetableZoom * 100).round()}%'),
              ),
              PopupMenuItem(
                value: 'zoom-in',
                enabled: _timetableZoom < 1.8,
                child: Text('放大行程表 · ${(_timetableZoom * 100).round()}%'),
              ),
            ],
            const PopupMenuItem(value: 'drag-help', child: Text('拖曳操作說明')),
            if (_isTracking) ...[
              const PopupMenuItem(value: 'progress', child: Text('確認進度')),
              PopupMenuItem(
                value: 'replan',
                enabled: !_isAlternativePromptOpen,
                child: const Text('重排剩餘行程'),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  void _handleAndroidToolbarAction(String action) {
    switch (action) {
      case 'hours':
        setState(() {
          _gapHoverTimer?.cancel();
          _expandedHours.clear();
          _expandAllHours = !_expandAllHours;
        });
        return;
      case 'zoom-out':
        _setZoom(-0.2);
        return;
      case 'zoom-in':
        _setZoom(0.2);
        return;
      case 'drag-help':
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('拖曳行程'),
            content: const Text('長按景點後拖到新的時間；頭尾收合的空白時段可點開，或拖曳停留後展開。鎖定時段不接受放置。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      case 'progress':
        _confirmTodayProgress();
        return;
      case 'replan':
        _requestRemainingAlternative();
        return;
    }
  }

  Future<void> _confirmTodayProgress() async {
    final now = _dependencies.now();
    final index = _itinerary.days.indexWhere(
      (day) =>
          day.date.year == now.year &&
          day.date.month == now.month &&
          day.date.day == now.day,
    );
    if (index >= 0) {
      await _confirmCompletedCount(_itinerary.days[index]);
    } else if (mounted) {
      _showMessage('目前日期不在這份行程內。');
    }
  }

  Future<void> _showTrackingStatus() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('行程追蹤'),
      content: const Text('GPS 追蹤中。保母系統會在此行程頁開啟期間檢查延誤與交通風險；備案須由你確認才會套用。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('關閉'),
        ),
      ],
    ),
  );

  void _setZoom(double delta) {
    final oldZoom = _timetableZoom;
    final oldOffset = _verticalController.hasClients
        ? _verticalController.offset
        : 0.0;
    setState(() => _timetableZoom = (_timetableZoom + delta).clamp(0.6, 1.8));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalController.hasClients) return;
      _verticalController.jumpTo(
        (oldOffset * _timetableZoom / oldZoom).clamp(
          0.0,
          _verticalController.position.maxScrollExtent,
        ),
      );
    });
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

  Widget _buildTimetable({bool singleDay = false}) {
    final startHour = _startHour;
    final endHour = _endHour;
    final height = (endHour - startHour) * _hourHeight;
    final width =
        _timeWidth + (singleDay ? 1 : _itinerary.days.length) * _dayWidth;
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
                  if (!singleDay) _buildHeader(),
                  SizedBox(
                    height: height,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimeAxis(startHour, endHour),
                        if (singleDay)
                          _buildDayColumn(_selectedDayIndex, startHour, endHour)
                        else
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

  Widget _buildCompactOverview() {
    // All days share one time axis. Collapse a boundary only when every day
    // is empty there, so visits in another column never disappear.
    final bands = compactDayBands(
      endHour: _endHour,
      visits: [
        for (final day in _itinerary.days)
          for (final visit in day.visits)
            (start: visit.startMinutes, end: visit.endMinutes),
      ],
      hourHeight: _hourHeight,
      gapHeight: max(48, MediaQuery.textScalerOf(context).scale(28) + 16),
      expandedHours: _expandedHours,
      expandAll: _expandAllHours,
    );
    final height = bands.last.top + bands.last.height;
    final width = _timeWidth + _itinerary.days.length * _dayWidth;

    void expand(CompactDayBand band) {
      if (!mounted) return;
      setState(() {
        for (var hour = band.startHour; hour < band.endHour; hour++) {
          _expandedHours.add(hour);
        }
      });
    }

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
                    child: Stack(
                      children: [
                        for (final band in bands)
                          Positioned(
                            top: band.top,
                            height: band.height,
                            left: 0,
                            right: 0,
                            child: band.collapsed
                                ? DragTarget<_DragData>(
                                    onWillAcceptWithDetails: (_) {
                                      _gapHoverTimer?.cancel();
                                      _gapHoverTimer = Timer(
                                        const Duration(milliseconds: 500),
                                        () => expand(band),
                                      );
                                      // Expand first; never assign an hour from
                                      // a compressed pixel position.
                                      return false;
                                    },
                                    onLeave: (_) => _gapHoverTimer?.cancel(),
                                    builder: (context, candidate, rejected) =>
                                        InkWell(
                                          onTap: () => expand(band),
                                          child: Container(
                                            alignment: Alignment.center,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainerLow,
                                            child: Text(
                                              '${band.startHour.toString().padLeft(2, '0')}:00–${band.endHour.toString().padLeft(2, '0')}:00 空白 · 點開／拖曳停留',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                  )
                                : Row(
                                    children: [
                                      SizedBox(
                                        width: _timeWidth,
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Text(
                                            '${band.startHour.toString().padLeft(2, '0')}:00',
                                          ),
                                        ),
                                      ),
                                      for (final day in _itinerary.days)
                                        SizedBox(
                                          width: _dayWidth,
                                          child: _buildDropCell(
                                            day,
                                            band.startHour,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        for (
                          var dayIndex = 0;
                          dayIndex < _itinerary.days.length;
                          dayIndex++
                        )
                          for (final visit in _itinerary.days[dayIndex].visits)
                            _buildVisit(
                              _itinerary.days[dayIndex],
                              visit,
                              0,
                              displayTop: compactMinuteOffset(
                                bands,
                                visit.startMinutes,
                              ),
                              displayHeight: max(
                                28,
                                compactMinuteOffset(bands, visit.endMinutes) -
                                    compactMinuteOffset(
                                      bands,
                                      visit.startMinutes,
                                    ) -
                                    4,
                              ),
                              displayLeft:
                                  _timeWidth + dayIndex * _dayWidth + 6,
                              displayRight:
                                  (_itinerary.days.length - dayIndex - 1) *
                                      _dayWidth +
                                  6,
                            ),
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

  Widget _buildCompactDay() {
    final day = _itinerary.days[_selectedDayIndex];
    final bands = compactDayBands(
      endHour: _endHour,
      visits: [
        for (final visit in day.visits)
          (start: visit.startMinutes, end: visit.endMinutes),
      ],
      hourHeight: _hourHeight,
      gapHeight: max(48, MediaQuery.textScalerOf(context).scale(28) + 16),
      expandedHours: _expandedHours,
      expandAll: _expandAllHours,
    );
    void expand(CompactDayBand band) {
      if (!mounted) return;
      setState(() {
        for (var h = band.startHour; h < band.endHour; h++) {
          _expandedHours.add(h);
        }
      });
    }

    return SingleChildScrollView(
      controller: _verticalController,
      child: SizedBox(
        height: bands.last.top + bands.last.height,
        child: Stack(
          children: [
            for (final band in bands)
              Positioned(
                top: band.top,
                height: band.height,
                left: 0,
                right: 0,
                child: band.collapsed
                    ? DragTarget<_DragData>(
                        onWillAcceptWithDetails: (_) {
                          _gapHoverTimer?.cancel();
                          _gapHoverTimer = Timer(
                            const Duration(milliseconds: 500),
                            () => expand(band),
                          );
                          // Never drop on a compressed interval: choose an actual hour after expansion.
                          return false;
                        },
                        onLeave: (_) => _gapHoverTimer?.cancel(),
                        builder: (context, candidate, rejected) => InkWell(
                          onTap: () => expand(band),
                          child: Container(
                            alignment: Alignment.center,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            child: Text(
                              '${band.startHour.toString().padLeft(2, '0')}:00–${band.endHour.toString().padLeft(2, '0')}:00 空白 · 點開／拖曳停留',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: _timeWidth,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '${band.startHour.toString().padLeft(2, '0')}:00',
                              ),
                            ),
                          ),
                          Expanded(child: _buildDropCell(day, band.startHour)),
                        ],
                      ),
              ),
            for (final visit in day.visits)
              _buildVisit(
                day,
                visit,
                0,
                displayTop: compactMinuteOffset(bands, visit.startMinutes),
                displayHeight: max(
                  28,
                  compactMinuteOffset(bands, visit.endMinutes) -
                      compactMinuteOffset(bands, visit.startMinutes) -
                      4,
                ),
                displayLeft: _timeWidth + 6,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: max(64, MediaQuery.textScalerOf(context).scale(40) + 16),
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

    final now = _dependencies.now();

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

  Widget _buildVisit(
    RouteDay day,
    RouteVisit visit,
    int startHour, {
    double? displayTop,
    double? displayHeight,
    double displayLeft = 6,
    double displayRight = 6,
  }) {
    final travelLegIndex = day.travelLegs.indexWhere(
      (leg) => leg.destination.id == visit.occurrenceId,
    );
    final top =
        displayTop ?? (visit.startMinutes - startHour * 60) / 60 * _hourHeight;
    final height =
        displayHeight ?? max(28.0, visit.stayMinutes / 60 * _hourHeight - 4);
    final card = _VisitCard(
      visit: visit,
      onTap: _isRecalculating ? null : () => _editVisitPreferences(visit),
      onShowTravel: travelLegIndex >= 0
          ? () => _showTravelLeg(day, travelLegIndex)
          : null,
      onDelete: _isRecalculating ? null : () => _deletePlace(visit.place),
    );
    return Positioned(
      left: displayLeft,
      right: displayRight,
      top: max(0.0, top),
      height: height,
      child:
          visit.locked ||
              visit.place.type == PlaceType.accommodation ||
              _isRecalculating
          ? card
          : MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: usesAndroidTripLayout
                  ? LongPressDraggable<_DragData>(
                      onDraggableCanceled: (_, _) {
                        _gapHoverTimer?.cancel();
                        if (mounted) setState(() => _expandedHours.clear());
                      },
                      onDragEnd: (_) {
                        _gapHoverTimer?.cancel();
                        if (mounted) setState(() => _expandedHours.clear());
                      },
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
                    )
                  : Draggable<_DragData>(
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
    final warnings = _itinerary.warnings
        .toSet()
        .where((message) => !message.contains('重複出現，已只保留一次'))
        .toList();
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.info_outline, size: 18),
        label: Text('${warnings.length} 項行程提醒 · 查看'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('行程提醒'),
            content: SingleChildScrollView(child: Text(warnings.join('\n\n'))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildGuardianDebugEntry() {
    final enabled = _dependencies.debugController?.enabled == true;
    return Container(
      width: double.infinity,
      color: enabled
          ? Colors.orange.shade100
          : Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 18,
            color: enabled ? Colors.orange.shade900 : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              enabled ? '保母模擬模式：假 GPS／班次；備案查真實 TDX' : 'Debug 保母測試工具',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Tooltip(
            message: '保母測試控制台',
            child: TextButton(
              onPressed: _showGuardianDebugConsole,
              child: const Text('開啟'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGuardianDebugConsole() async {
    final controller = _dependencies.debugController;
    if (!kDebugMode || controller == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .9,
        child: GuardianDebugConsole(
          controller: controller,
          itinerary: _itinerary,
          isTracking: _isTracking,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startTracking() async {
    if (_isStartingTracking || _isTracking) return;
    setState(() => _isStartingTracking = true);
    try {
      _hasReportedWeatherError = false;
      if (_dependencies.debugController?.enabled != true) {
        await _showInitialWeatherOverview();
        if (!mounted) return;
      }
      if (usesAndroidTripLayout) {
        try {
          await _dependencies.notificationGateway.initialize();
          final enabled = await _dependencies.notificationGateway
              .androidNotificationsEnabled();
          if (!mounted) return;
          if (enabled == false) _showMessage('通知未開啟；仍可追蹤行程，可至手機設定允許通知。');
        } catch (_) {
          if (!mounted) return;
          _showMessage('通知暫時無法啟用，仍可使用行程追蹤。');
        }
      }
      if (!mounted) return;
      final started = await _tripTracker.start(_itinerary);
      if (!mounted) return;
      if (!started) {
        _showMessage('無法取得 GPS 位置，請確認已開啟定位服務並允許位置權限。');
        return;
      }
      if (usesAndroidTripLayout) {
        final session = ActiveGuardianSession(
          tracker: _tripTracker,
          dependencies: _dependencies,
          itinerary: _itinerary,
        );
        await session.activate();
        _guardianSession = session;
        session.attachPage(onResume: _resumePendingGuardianRisk);
      }
      setState(() {
        _isTracking = true;
        _isMapVisible = true;
      });
      _showMessage('已開始 GPS 行程追蹤；若明顯延誤，系統會提供備案，由你確認後才會套用。');
      if (usesAndroidTripLayout && !_dependencies.weatherGateway.isConfigured) {
        _showMessage('天氣提醒尚未設定，GPS 行程追蹤可正常使用。');
      }
    } catch (_) {
      if (mounted) _showMessage('暫時無法開始追蹤，請確認定位權限後重試。');
    } finally {
      if (mounted) setState(() => _isStartingTracking = false);
    }
  }

  Future<void> _stopTracking() async {
    final session = _guardianSession;
    if (session != null) {
      await session.stop();
      _guardianSession = null;
    } else {
      await _tripTracker.stop();
    }
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

  void _resumePendingGuardianRisk() {
    if (!mounted || _isAlternativePromptOpen || _isEvaluatingTrackingUpdate)
      return;
    final pending = _guardianSession?.takePendingRiskUpdate();
    if (pending != null) unawaited(_handleTrackingUpdate(pending));
  }

  void _updateTrackedItinerary(RouteItinerary itinerary) {
    if (_guardianSession != null) {
      _guardianSession!.updateItinerary(itinerary);
    } else {
      _tripTracker.updateItinerary(itinerary);
    }
  }

  /// The traveller confirms a contiguous completed prefix. GPS proximity or
  /// the scheduled end time alone must not silently mark a visit complete.
  Future<int?> _confirmCompletedCount(RouteDay day) async {
    var count = (_confirmedCompletedCounts[day.day] ?? 0).clamp(
      0,
      day.visits.length,
    );
    final selected = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('確認今天的行程進度'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '請選擇最後一個已完成的項目；系統不會只因原訂時間已過或 GPS 靠近就判定完成。正在進行的項目請勿選入。',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('尚無已完成項目'),
                    leading: Icon(
                      count == 0
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    onTap: () => setDialogState(() => count = 0),
                  ),
                  for (var index = 0; index < day.visits.length; index++)
                    ListTile(
                      title: Text('已完成至 ${day.visits[index].label}'),
                      leading: Icon(
                        count == index + 1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => setDialogState(() => count = index + 1),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(count),
              child: const Text('確認進度'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) _confirmedCompletedCounts[day.day] = selected;
    return selected;
  }

  Future<void> _requestRemainingAlternative() async {
    if (_isAlternativePromptOpen) return;
    final location = _currentLocation;
    if (location == null) {
      _showMessage('尚未取得目前位置，請稍後再試。');
      return;
    }
    final now = _dependencies.now();

    final dayIndex = _itinerary.days.indexWhere(
      (day) =>
          day.date.year == now.year &&
          day.date.month == now.month &&
          day.date.day == now.day,
    );
    if (dayIndex < 0) {
      _showMessage('目前日期不在這份行程內，無法重排今日剩餘行程。');
      return;
    }
    _isAlternativePromptOpen = true;
    try {
      final day = _itinerary.days[dayIndex];
      final completedCount = await _confirmCompletedCount(day);
      if (!mounted || completedCount == null) return;
      var plan = await _alternativePlanner.plan(
        day: day,
        currentLocation: location,
        now: now,
        completedCount: completedCount,
        strategy: LiveAlternativeStrategy.preserveOrder,
      );
      if (!plan.canApply && plan.needsNewLegMode) {
        final mode = await _chooseNewLegMode();
        if (!mounted || mode == null) return;
        plan = await _alternativePlanner.plan(
          day: day,
          currentLocation: location,
          now: now,
          completedCount: completedCount,
          strategy: LiveAlternativeStrategy.preserveOrder,
          newLegMode: mode,
        );
      }
      if (!plan.canApply && plan.reorderMayHelp) {
        final mode = await _chooseNewLegMode();
        if (!mounted || mode == null) return;
        plan = await _alternativePlanner.plan(
          day: day,
          currentLocation: location,
          now: now,
          completedCount: completedCount,
          strategy: LiveAlternativeStrategy.reorderRemaining,
          newLegMode: mode,
        );
      }
      if (!mounted) return;
      if (!plan.canApply) {
        await _showPlanningFailure(plan.failure ?? '目前無法產生經路線查詢驗證的備案。');
        return;
      }
      final revisedDay = plan.day!;
      final shouldApply = await _confirmAlternative(
        originalDay: day,
        revisedDay: revisedDay,
        reason: '你要求依目前位置與時間重新檢查今天的剩餘行程。',
        nowMinute: now.hour * 60 + now.minute,
      );
      if (!mounted) return;
      if (!shouldApply) {
        _showMessage('已保留原行程，尚未變更任何安排。');
        return;
      }
      final revisedDays = List<RouteDay>.of(_itinerary.days)
        ..[dayIndex] = revisedDay;
      final revisedModes = _modesFromDays(revisedDays);
      final revised = RouteItinerary(
        request: _itinerary.request,
        origin: _itinerary.origin,
        days: revisedDays,
        generatedAt: _dependencies.now(),

        warnings: _itinerary.warnings,
        inputs: _itinerary.inputs,
        travelModeOverrides: revisedModes,
      );
      _updateTrackedItinerary(revised);
      setState(() {
        _itinerary = revised;
        _travelModeOverrides = revisedModes;
        _selectedDayIndex = dayIndex;
        _mapDayIndex = dayIndex;
      });
      _showMessage('已套用 Day ${revisedDay.day} 的剩餘行程備案。');
    } catch (_) {
      await _showPlanningFailure('暫時無法重新查詢剩餘行程。');
    } finally {
      if (mounted) setState(() => _isAlternativePromptOpen = false);
    }
  }

  Future<void> _handleTrackingUpdate(TripTrackingUpdate update) async {
    if (!mounted ||
        (_guardianSession != null && !_guardianSession!.isForegroundVisible)) {
      return;
    }
    setState(() {
      _currentLocation = update.location;
      _trackedRoute = update.route;
    });
    if (_isEvaluatingTrackingUpdate || _isAlternativePromptOpen) return;
    _isEvaluatingTrackingUpdate = true;
    try {
      final now = _dependencies.now();
      try {
        if (_dependencies.debugController?.enabled == true ||
            _dependencies.productionWeatherService == null) {
          await _dependencies.weatherGateway.check(update.location, now: now);
        } else {
          final weather = await _checkWeatherAtCurrentLocation(update.location);
          if (weather != null && mounted && weather.advisories.isNotEmpty) {
            await _showWeatherAdvisory(weather.advisories);
          } else if (weather == null &&
              _weatherAdvisoryService.lastError != null) {
            _reportWeatherErrorOnce();
          }
        }
      } catch (_) {
        // Weather availability must not prevent GPS and transport monitoring.
      }
      if (!mounted) return;
      final dayIndex = _itinerary.days.indexWhere(
        (day) =>
            day.date.year == now.year &&
            day.date.month == now.month &&
            day.date.day == now.day,
      );
      if (dayIndex >= 0) {
        TransitConnectionRisk? transitRisk;
        try {
          transitRisk = await _transitGuardian.check(
            day: _itinerary.days[dayIndex],
            location: update.location,
            now: now,
          );
          _realtimeWarningShown = false;
        } catch (_) {
          if (!_realtimeWarningShown && mounted) {
            _realtimeWarningShown = true;
            _showMessage('即時班次資料暫時無法取得；GPS 延誤仍會繼續監測。');
          }
        }
        if (!mounted) return;
        if (transitRisk != null) {
          final riskKey =
              '${transitRisk.kind.name}|${transitRisk.affectedSection.stableKey}';
          final previousPrompt = _lastTransitRiskPromptAt[riskKey];
          if (previousPrompt != null &&
              !now.isBefore(previousPrompt) &&
              now.difference(previousPrompt) < const Duration(minutes: 15)) {
            return;
          }
          _lastTransitRiskPromptAt[riskKey] = now;
          await _handleTransitRisk(
            risk: transitRisk,
            location: update.location,
            now: now,
            dayIndex: dayIndex,
          );
          return;
        }
      }
      final alert = update.delayAlert;
      if (alert == null || _isAlternativePromptOpen) return;
      if (dayIndex < 0) return;

      _isAlternativePromptOpen = true;
      try {
        final day = _itinerary.days[dayIndex];
        final completedCount = await _confirmCompletedCount(day);
        if (!mounted || completedCount == null) return;
        var plan = await _alternativePlanner.plan(
          day: day,
          currentLocation: update.location,
          now: now,
          completedCount: completedCount,
          strategy: LiveAlternativeStrategy.preserveOrder,
        );
        if (!plan.canApply && plan.needsNewLegMode) {
          final mode = await _chooseNewLegMode();
          if (!mounted || mode == null) return;
          plan = await _alternativePlanner.plan(
            day: day,
            currentLocation: update.location,
            now: now,
            completedCount: completedCount,
            strategy: LiveAlternativeStrategy.preserveOrder,
            newLegMode: mode,
          );
        }
        if (!plan.canApply && plan.reorderMayHelp) {
          final newLegMode = await _chooseNewLegMode();
          if (!mounted || newLegMode == null) return;
          plan = await _alternativePlanner.plan(
            day: day,
            currentLocation: update.location,
            now: now,
            completedCount: completedCount,
            strategy: LiveAlternativeStrategy.reorderRemaining,
            newLegMode: newLegMode,
          );
        }
        if (!mounted) return;
        if (!plan.canApply) {
          await _showPlanningFailure(plan.failure ?? '目前無法產生經路線查詢驗證的備案。');
          return;
        }
        final revisedDay = plan.day!;
        final revisedDays = List.of(_itinerary.days)..[dayIndex] = revisedDay;
        final revisedModes = _modesFromDays(revisedDays);
        final revised = RouteItinerary(
          request: _itinerary.request,
          origin: _itinerary.origin,
          days: revisedDays,
          generatedAt: _dependencies.now(),
          warnings: _itinerary.warnings,
          inputs: _itinerary.inputs,
          travelModeOverrides: revisedModes,
        );
        if (!mounted) return;
        try {
          await _dependencies.notificationGateway.showAlternativeAvailable(
            lateMinutes: alert.lateMinutes,
            nextStopName: alert.nextStopName,
          );
        } catch (_) {
          // 通知失敗不應阻止使用者在 App 內查看及決定是否套用備案。
        }
        if (!mounted) return;
        final shouldApply = await _confirmAlternative(
          originalDay: _itinerary.days[dayIndex],
          revisedDay: revisedDay,
          reason:
              '目前約晚了 ${alert.lateMinutes} 分鐘，可能無法依原訂時間前往「${alert.nextStopName}」。',
          nowMinute: now.hour * 60 + now.minute,
        );
        if (!mounted) return;
        if (shouldApply) {
          _updateTrackedItinerary(revised);
          setState(() {
            _itinerary = revised;
            _travelModeOverrides = revisedModes;
            _selectedDayIndex = dayIndex;
            _mapDayIndex = dayIndex;
          });
          _showMessage('已套用 Day ${revisedDay.day} 的行程備案。');
        } else {
          _showMessage('已保留原行程，尚未變更任何安排。');
        }
      } catch (_) {
        await _showPlanningFailure('偵測到延誤，但暫時無法產生今日行程備案。');
      } finally {
        if (mounted) setState(() => _isAlternativePromptOpen = false);
      }
    } finally {
      _isEvaluatingTrackingUpdate = false;
    }
  }

  Future<void> _handleTransitRisk({
    required TransitConnectionRisk risk,
    required LocationPoint location,
    required DateTime now,
    required int dayIndex,
  }) async {
    _isAlternativePromptOpen = true;
    try {
      try {
        await _dependencies.notificationGateway.showTransitRisk(
          reason: risk.reason,
          nextStopName: risk.affectedSection.section.arrivalTitle ?? '下一個目的地',
        );
      } catch (_) {
        // App 內仍會顯示備案；通知權限不影響主要流程。
      }
      final day = _itinerary.days[dayIndex];
      final options = await _transitAlternativeService.options(
        day: day,
        risk: risk,
        currentLocation: location,
        now: now,
      );
      if (!mounted) return;
      if (options.isEmpty) {
        await _showPlanningFailure('偵測到轉乘風險，但目前查不到可用的即時交通備案。');
        return;
      }
      final selected = await _chooseTransitAlternative(
        risk: risk,
        options: options.take(3).toList(growable: false),
      );
      if (!mounted) return;
      if (selected == null) {
        _showMessage('已保留原行程，尚未變更任何安排。');
        return;
      }
      _showMessage('正在計算所選交通備案的完整後續行程…');
      final completedCount = await _confirmCompletedCount(day);
      if (!mounted || completedCount == null) return;
      final alternativeStart = _transitAlternativeService.startForRisk(
        day: day,
        risk: risk,
        currentLocation: location,
        now: now,
      );
      var plan = await _alternativePlanner.plan(
        day: day,
        currentLocation: location,
        now: now,
        completedCount: completedCount,
        strategy: LiveAlternativeStrategy.preserveOrder,
        affectedLegIndex: risk.affectedSection.legIndex,
        selectedFirstRoute: selected,
        firstOrigin: alternativeStart.origin,
        firstDeparture: alternativeStart.departure,
        preservedFirstSections: risk.affectedSection.sectionIndex,
      );
      if (!mounted) return;
      if (!plan.canApply && plan.reorderMayHelp) {
        final mode = await _chooseNewLegMode();
        if (!mounted || mode == null) return;
        plan = await _alternativePlanner.plan(
          day: day,
          currentLocation: location,
          now: now,
          completedCount: completedCount,
          strategy: LiveAlternativeStrategy.reorderRemaining,
          affectedLegIndex: risk.affectedSection.legIndex,
          selectedFirstRoute: selected,
          newLegMode: mode,
          firstOrigin: alternativeStart.origin,
          firstDeparture: alternativeStart.departure,
          preservedFirstSections: risk.affectedSection.sectionIndex,
          keepFirstRemaining: true,
        );
      }
      if (!mounted) return;
      if (!plan.canApply) {
        await _showPlanningFailure(plan.failure ?? '後續路段無法完整銜接。');
        return;
      }
      final revisedDay = plan.day!;
      final shouldApply = await _confirmAlternative(
        originalDay: day,
        revisedDay: revisedDay,
        reason: risk.reason,
        nowMinute: now.hour * 60 + now.minute,
        affectedLegIndex: risk.affectedSection.legIndex,
      );
      if (!mounted) return;
      if (!shouldApply) {
        _showMessage('已保留原行程，尚未變更任何安排。');
        return;
      }
      final revisedDays = List<RouteDay>.of(_itinerary.days)
        ..[dayIndex] = revisedDay;
      final revisedModes = _modesFromDays(revisedDays);
      final revised = RouteItinerary(
        request: _itinerary.request,
        origin: _itinerary.origin,
        days: revisedDays,
        generatedAt: _dependencies.now(),
        warnings: _itinerary.warnings,
        inputs: _itinerary.inputs,
        travelModeOverrides: revisedModes,
      );
      _updateTrackedItinerary(revised);
      setState(() {
        _itinerary = revised;
        _travelModeOverrides = revisedModes;
        _selectedDayIndex = dayIndex;
        _mapDayIndex = dayIndex;
      });
      _showMessage('已套用 Day ${revisedDay.day} 的交通備案。');
    } catch (_) {
      await _showPlanningFailure('即時交通資料暫時無法取得。');
    } finally {
      if (mounted) setState(() => _isAlternativePromptOpen = false);
    }
  }

  Future<void> _showPlanningFailure(String reason) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('暫時無法產生備案'),
        content: Text('$reason\n\n原行程沒有變更。你可以稍後重試，或在結果頁選擇其他交通方式與調整行程。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<TdxRoute?> _chooseTransitAlternative({
    required TransitConnectionRisk risk,
    required List<TdxRoute> options,
  }) async {
    var selectedIndex = 0;
    return showDialog<TdxRoute>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('可能趕不上原班次'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(risk.reason),
                  const SizedBox(height: 8),
                  const Text('先選擇路線預覽完整變更；此步驟不會修改原行程。'),
                  const SizedBox(height: 12),
                  for (var index = 0; index < options.length; index++)
                    ListTile(
                      selected: selectedIndex == index,
                      onTap: () => setDialogState(() => selectedIndex = index),
                      leading: Icon(
                        selectedIndex == index
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text('備案 ${index + 1}'),
                      subtitle: Text(_transitOptionSummary(options[index])),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('保留原行程'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(options[selectedIndex]),
              child: const Text('預覽所選備案'),
            ),
          ],
        ),
      ),
    );
  }

  Future<RouteTravelMode?> _chooseNewLegMode() => showDialog<RouteTravelMode>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('新路段要怎麼移動？'),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text('原路段會保留原交通模式；新相鄰的景點需要你選擇交通方式。'),
        ),
        for (final mode in RouteTravelMode.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(mode),
            child: Text(mode.label),
          ),
      ],
    ),
  );

  String _transitOptionSummary(TdxRoute route) {
    final start = route.startTime;
    final end = route.endTime;
    final time = start != null && end != null
        ? '${_dateTimeHm(start)}–${_dateTimeHm(end)}'
        : '約 ${(route.travelTime / 60).ceil()} 分鐘';
    final lines = route.sections
        .where((section) => section.mode != 'pedestrian')
        .map((section) => section.lineName)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .join(' → ');
    return [
      time,
      if (lines.isNotEmpty) lines,
      '轉乘 ${route.transfers} 次',
    ].join('・');
  }

  String _dateTimeHm(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  Map<RouteLegKey, RouteTravelMode> _modesFromDays(List<RouteDay> days) => {
    for (final day in days)
      for (final leg in day.travelLegs)
        routeLegKey(
          day: day.day,
          originId: leg.origin.id,
          destinationId: leg.destination.id,
        ): leg.travelMode,
  };

  Future<bool> _confirmAlternative({
    required RouteDay originalDay,
    required RouteDay revisedDay,
    required String reason,
    required int nowMinute,
    int? affectedLegIndex,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('行程備案'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason),
                    const SizedBox(height: 10),
                    const Text('以下只對照受影響的後續行程；已完成項目與其他日期不變。按「套用備案」前不會修改原行程。'),
                    const SizedBox(height: 16),
                    _buildItineraryComparison(
                      originalDay: originalDay,
                      revisedDay: revisedDay,
                      nowMinute: nowMinute,
                      affectedLegIndex: affectedLegIndex,
                    ),
                    for (final warning in revisedDay.warnings.where(
                      (item) => !originalDay.warnings.contains(item),
                    )) ...[const SizedBox(height: 8), Text('注意：$warning')],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('保留原行程'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('套用備案'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildItineraryComparison({
    required RouteDay originalDay,
    required RouteDay revisedDay,
    required int nowMinute,
    int? affectedLegIndex,
  }) {
    final originalEntries = _comparisonEntries(
      originalDay,
      nowMinute: nowMinute,
      affectedLegIndex: affectedLegIndex,
    );
    final revisedEntries = _comparisonEntries(
      revisedDay,
      nowMinute: nowMinute,
      affectedLegIndex: affectedLegIndex,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _comparisonPanel('原行程 Before', originalEntries),
        const SizedBox(height: 12),
        _comparisonPanel('建議行程 After', revisedEntries),
      ],
    );
  }

  Widget _comparisonPanel(String title, List<_ComparisonEntry> entries) =>
      Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (entries.isEmpty) const Text('沒有受影響的後續項目。'),
              for (final entry in entries)
                if (entry.details == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(entry.title),
                  )
                else
                  ExpansionTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    leading: Icon(entry.icon, size: 20),
                    title: Text(entry.title, maxLines: 2),
                    subtitle: Text(entry.subtitle!),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(entry.details!),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      );

  List<_ComparisonEntry> _comparisonEntries(
    RouteDay day, {
    required int nowMinute,
    int? affectedLegIndex,
  }) {
    final entries = <_ComparisonEntry>[];
    for (var index = 0; index < day.travelLegs.length; index++) {
      final leg = day.travelLegs[index];
      if (affectedLegIndex != null
          ? index < affectedLegIndex
          : leg.schedule.arrivalMinutes <= nowMinute) {
        continue;
      }
      final routeLines = leg.route?.sections
          .map((section) => section.lineName)
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .join(' → ');
      final transport = leg.route == null
          ? '交通時間估計'
          : routeLines != null && routeLines.isNotEmpty
          ? routeLines
          : leg.travelMode.label;
      final travelMinutes =
          leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
      entries.add((
        startMinutes: leg.schedule.departureMinutes,
        title:
            '${_formatMinutes(leg.schedule.departureMinutes)}–'
            '${_formatMinutes(leg.schedule.arrivalMinutes)} '
            '前往${leg.destination.name}',
        subtitle: '${leg.travelMode.label} · $travelMinutes 分鐘',
        details: '起點：${leg.origin.name}\n路線：$transport',
        icon: switch (leg.travelMode) {
          RouteTravelMode.transit => Icons.directions_transit,
          RouteTravelMode.walking => Icons.directions_walk,
          RouteTravelMode.driving => Icons.directions_car,
        },
      ));
    }
    for (final visit in day.visits) {
      if (visit.endMinutes <= nowMinute) continue;
      entries.add((
        startMinutes: visit.startMinutes,
        title:
            '${_formatMinutes(visit.startMinutes)}–'
            '${_formatMinutes(visit.endMinutes)} ${visit.label}',
        subtitle: null,
        details: null,
        icon: null,
      ));
    }
    entries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return entries;
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
    setState(() {
      _pendingPlaces.addAll(newPlaces);
      if (usesAndroidTripLayout) _androidOverview = true;
    });
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
      _updateTrackedItinerary(result);
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
        if (usesAndroidTripLayout) {
          return Card(
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
                        visit.label,
                        maxLines: constraints.maxHeight > 70 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        tooltip: '項目操作',
                        onSelected: (value) {
                          if (value == 'edit') onTap?.call();
                          if (value == 'travel') onShowTravel?.call();
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            enabled: onTap != null,
                            child: const Text('設定／資訊'),
                          ),
                          if (onShowTravel != null)
                            const PopupMenuItem(
                              value: 'travel',
                              child: Text('交通方式'),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            enabled: onDelete != null,
                            child: const Text('移除'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        // Expanded cards require room for two title lines, time and action.
        if (constraints.maxHeight >= 60 + 90 * textScale &&
            constraints.maxWidth >= 240 * textScale) {
          return expandedCard;
        }
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
