import 'dart:math';
import 'dart:async';
import '../models/compact_day_axis.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/trip/android_layout.dart';
import '../widgets/android_day_itinerary.dart';

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
import '../models/itinerary_edit_result.dart';
import '../services/ai_itinerary_edit_service.dart';
import '../services/itinerary_edit_validator.dart';
import '../models/itinerary_edit_command.dart';
import '../services/itinerary_edit_executor.dart';
import '../services/relax_day_planner.dart';
import '../services/itinerary_place_resolver.dart';
import '../../../services/place_service.dart';
import '../services/itinerary_place_candidate_ranker.dart';

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
typedef ResolveItineraryPlaceQuery =
    Future<List<ItineraryPlaceMatch>> Function(
      String query,
      Set<String> excludedPlaceIds,
    );
typedef RequestIndoorItineraryAlternatives =
    Future<void> Function(WeatherIndoorItineraryRequest request);

class ItineraryResultPage extends StatefulWidget {
  final RouteItinerary itinerary;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final AddItineraryPlaces? onAddPlace;
  final RecalculateItinerary? onRecalculate;
  final ResolveItineraryPlaceQuery? onResolvePlaceQuery;

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
    this.onResolvePlaceQuery,
    this.onRequestIndoorItineraryAlternatives,
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
  final _tripTracker = LiveItineraryTrackingService();
  final _notificationService = TripNotificationService();
  late final WeatherAdvisoryService _weatherAdvisoryService;
  late final Future<TaiwanCountyResolver> _countyResolver;
  final _liveDayReplanner = LiveDayItineraryReplanner();
  final _aiEditService = AiItineraryEditService();
  final _itineraryEditValidator = const ItineraryEditValidator();
  final _itineraryEditExecutor = const ItineraryEditExecutor();
  final _relaxDayPlanner = const RelaxDayPlanner();
  final _itineraryPlaceCandidateRanker = const ItineraryPlaceCandidateRanker();

  bool _isParsingAiEdit = false;

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
    _gapHoverTimer?.cancel();
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
                        : _buildTimetable(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToolbar() {
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

          OutlinedButton.icon(
            onPressed: _isRecalculating || _isParsingAiEdit
                ? null
                : _requestAiEdit,
            icon: _isParsingAiEdit
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isParsingAiEdit ? '正在理解修改要求...' : 'AI 協助修改'),
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

    return Column(
      children: [
        TextButton(
          onPressed: () => setState(() {
            _gapHoverTimer?.cancel();
            _expandedHours.clear();
            _expandAllHours = !_expandAllHours;
          }),
          child: Text(_expandAllHours ? '壓縮空白時段' : '展開全部時段'),
        ),
        Expanded(
          child: SingleChildScrollView(
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
                                Expanded(
                                  child: _buildDropCell(day, band.startHour),
                                ),
                              ],
                            ),
                    ),
                  for (final visit in day.visits)
                    _buildVisit(
                      day,
                      visit,
                      0,
                      displayTop: compactMinuteOffset(
                        bands,
                        visit.startMinutes,
                      ),
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
          ),
        ),
      ],
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

  Widget _buildVisit(
    RouteDay day,
    RouteVisit visit,
    int startHour, {
    double? displayTop,
    double? displayHeight,
    double displayLeft = 6,
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

  Future<void> _requestAiEdit() async {
    if (_isParsingAiEdit || _isRecalculating) {
      return;
    }

    final controller = TextEditingController();

    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome),
              SizedBox(width: 8),
              Expanded(child: Text('AI 協助修改行程')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '例如：把故宮移到第二天下午，並刪除西門町',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('分析修改要求'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || input == null || input.trim().isEmpty) {
      return;
    }

    setState(() {
      _isParsingAiEdit = true;
    });

    try {
      var requestText = input;
      ItineraryEditResult? parsedResult;

      for (var attempt = 0; attempt < 3; attempt++) {
        final currentResult = await _aiEditService.parseEdit(
          text: requestText,
          itinerary: _itinerary,
        );

        if (!mounted) {
          return;
        }

        if (!currentResult.needsClarification) {
          parsedResult = currentResult;
          break;
        }

        final answer = await _showAiClarification(currentResult);

        if (!mounted || answer == null || answer.trim().isEmpty) {
          return;
        }

        requestText =
            '''
原始修改要求：
$input

AI 詢問：
${currentResult.clarificationQuestion ?? '請補充修改資訊'}

使用者補充：
${answer.trim()}
''';
      }

      if (parsedResult == null) {
        _showMessage('補充資訊後仍無法理解修改要求，請重新描述。');
        return;
      }

      final result = parsedResult;

      // 先處理 addPlace 指令，把 placeQuery 轉成真正的 Place。
      final resolvedAddPlaces = await _resolveAddPlaceCommands(result);

      if (!mounted || resolvedAddPlaces == null) {
        return;
      }

      // 將選好的景點傳入修改預覽。
      final confirmed = await _showAiEditPreview(
        result,
        resolvedAddPlaces: resolvedAddPlaces,
      );

      if (!confirmed || !mounted) {
        return;
      }

      // 使用者確認後，才將景點交給 Executor 套用。
      await _applyAiEditResult(result, resolvedAddPlaces: resolvedAddPlaces);
    } on AiItineraryEditException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('無法理解修改要求：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isParsingAiEdit = false;
        });
      }
    }
  }

  Future<String?> _showAiClarification(ItineraryEditResult result) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final answer = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline),
              SizedBox(width: 8),
              Expanded(child: Text('AI 需要更多資訊')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.clarificationQuestion ?? '請補充行程修改資訊。'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '你的回答',
                      hintText: '例如：第二天下午兩點',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '請輸入回答';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (formKey.currentState?.validate() == true) {
                        Navigator.of(dialogContext).pop(controller.text.trim());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消修改'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              icon: const Icon(Icons.send),
              label: const Text('送出回答'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return answer;
  }

  Future<bool> _showAiEditPreview(
    ItineraryEditResult result, {
    required Map<int, Place> resolvedAddPlaces,
  }) async {
    final validation = _itineraryEditValidator.validate(
      result: result,
      itinerary: _itinerary,
    );

    final previewErrors = <String>[...validation.errors];

    final relaxDayPlans = <int, RelaxDayPlan>{};

    for (var index = 0; index < result.commands.length; index++) {
      final command = result.commands[index];

      if (command.action != ItineraryEditAction.relaxDay) {
        continue;
      }

      final targetDay = command.targetDay;

      if (targetDay == null) {
        continue;
      }

      final plan = _relaxDayPlanner.createPlan(
        itinerary: _itinerary,
        day: targetDay,
      );

      relaxDayPlans[index] = plan;

      if (!plan.canApply) {
        previewErrors.add(
          '第 ${index + 1} 項修改：'
          '${plan.error ?? '無法產生放鬆行程方案。'}',
        );
      }
    }

    final canApply = previewErrors.isEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                canApply
                    ? Icons.fact_check_outlined
                    : Icons.warning_amber_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(canApply ? '確認 AI 理解結果' : '修改要求無法套用')),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.summary.isNotEmpty) ...[
                    Text(
                      result.summary,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!canApply) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '發現以下問題：',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 8),

                          for (final error in previewErrors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $error',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'AI 解析出的修改：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  for (var index = 0; index < result.commands.length; index++)
                    _buildAiCommandPreview(
                      index: index,
                      command: result.commands[index],
                      additionalDetail: relaxDayPlans[index]?.canApply == true
                          ? relaxDayPlans[index]!.explanation
                          : resolvedAddPlaces[index] != null
                          ? _addPlacePreviewText(
                              result.commands[index],
                              resolvedAddPlaces[index]!,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('返回'),
            ),

            if (canApply)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.check),
                label: const Text('套用並重新排行程'),
              ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  String _addPlacePreviewText(ItineraryEditCommand command, Place place) {
    final details = <String>['將新增「${place.name}」'];

    final county = PlaceService.countyFor(place);

    if (county.isNotEmpty) {
      details.add(county);
    }

    if (place.category.isNotEmpty) {
      details.add(place.category);
    }

    if (command.targetDay != null) {
      details.add('安排至 Day ${command.targetDay}');
    }

    if (command.targetStartMinutes != null) {
      details.add(_formatMinutes(command.targetStartMinutes!));
    }

    if (_isOutsidePreferredLocation(place)) {
      details.add('提醒：此景點不在預設旅遊範圍內');
    }

    return details.join('・');
  }

  String _aiEditActionLabel(String action) {
    switch (action) {
      case 'movePlace':
        return '移動景點';

      case 'removePlace':
        return '移除景點';

      case 'addPlace':
        return '新增景點';

      case 'replacePlace':
        return '替換景點';

      case 'changeDuration':
        return '修改停留時間';

      case 'lockPlace':
        return '鎖定景點時間';

      case 'unlockPlace':
        return '解除景點鎖定';

      case 'relaxDay':
        return '放鬆單日行程';

      case 'changeTravelMode':
        return '修改交通方式';

      default:
        return '無法辨識的修改';
    }
  }

  Widget _buildAiCommandPreview({
    required int index,
    required ItineraryEditCommand command,
    String? additionalDetail,
  }) {
    final details = <String>[];

    if (command.placeName != null) {
      details.add('景點：${command.placeName}');
    }

    if (command.placeQuery != null) {
      details.add('搜尋：${command.placeQuery}');
    }

    if (command.targetDay != null) {
      details.add('Day ${command.targetDay}');
    }

    if (command.targetStartMinutes != null) {
      details.add('時間：${_formatMinutes(command.targetStartMinutes!)}');
    }

    if (command.durationMinutes != null) {
      details.add('停留：${command.durationMinutes} 分鐘');
    }

    if (command.destinationPlaceName != null) {
      details.add('目的地：${command.destinationPlaceName}');
    }

    if (command.travelMode != null) {
      details.add('交通：${_travelModeLabel(command.travelMode!)}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(_aiEditActionLabel(command.action.name)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty) Text(details.join('・')),

            if (command.reason != null) ...[
              const SizedBox(height: 4),
              Text(command.reason!),
            ],

            if (additionalDetail != null &&
                additionalDetail.trim().isNotEmpty) ...[
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(additionalDetail)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _travelModeLabel(String mode) {
    switch (mode) {
      case 'walking':
        return '步行';

      case 'driving':
        return '開車';

      case 'transit':
        return '大眾運輸';

      default:
        return mode;
    }
  }

  Future<void> _applyAiEditResult(
    ItineraryEditResult result, {
    required Map<int, Place> resolvedAddPlaces,
  }) async {
    if (_isRecalculating) {
      return;
    }

    final execution = _itineraryEditExecutor.execute(
      editResult: result,
      currentConstraints: _constraints,
      currentTravelModeOverrides: _travelModeOverrides,
      itinerary: _itinerary,
      resolvedPlaces: resolvedAddPlaces,
    );

    if (!execution.isSuccessful) {
      await _showAiExecutionErrors(execution.errors);
      return;
    }

    if (execution.constraints.isEmpty) {
      _showMessage('行程中至少需要保留一個景點。');
      return;
    }

    final constraintsBackup = _copyConstraints(_constraints);

    final travelModeBackup = Map<RouteLegKey, RouteTravelMode>.of(
      _travelModeOverrides,
    );

    setState(() {
      _constraints = _copyConstraints(execution.constraints);

      _travelModeOverrides = Map<RouteLegKey, RouteTravelMode>.of(
        execution.travelModeOverrides,
      );
    });

    final succeeded = await _recalculate();

    if (!succeeded && mounted) {
      setState(() {
        _constraints = constraintsBackup;
        _travelModeOverrides = travelModeBackup;
      });

      return;
    }

    if (mounted) {
      final message = execution.appliedMessages.isEmpty
          ? '已依照 AI 修改要求重新安排行程。'
          : execution.appliedMessages.join('\n');

      _showMessage(message);
    }
  }

  Future<void> _showAiExecutionErrors(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(width: 8),
              Expanded(child: Text('暫時無法套用修改')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('修改要求已經理解，但仍需要完成以下處理：'),
                const SizedBox(height: 12),

                for (final error in errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $error'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  Future<Place?> _showAiPlaceCandidateDialog({
    required String query,
    required List<ItineraryPlaceMatch> matches,
  }) {
    return showDialog<Place>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('選擇「$query」對應的景點'),
          content: SizedBox(
            width: 560,
            height: 420,
            child: ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final match = matches[index];
                final place = match.place;
                final county = PlaceService.countyFor(place);
                final outsidePreferredLocation = _isOutsidePreferredLocation(
                  place,
                );

                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(place.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          if (county.isNotEmpty) county,
                          if (place.category.isNotEmpty) place.category,
                          match.reason,
                        ].join('・'),
                      ),
                      if (outsidePreferredLocation)
                        Text(
                          '此景點不在預設旅遊範圍內',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(match.score.toStringAsFixed(0)),
                  onTap: () {
                    Navigator.of(dialogContext).pop(place);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<int, Place>?> _resolveAddPlaceCommands(
    ItineraryEditResult result,
  ) async {
    final resolvedPlaces = <int, Place>{};

    for (var index = 0; index < result.commands.length; index++) {
      final command = result.commands[index];

      if (command.action != ItineraryEditAction.addPlace) {
        continue;
      }

      final query = command.placeQuery?.trim().isNotEmpty == true
          ? command.placeQuery!.trim()
          : command.placeName?.trim();

      if (query == null || query.isEmpty) {
        _showMessage('第 ${index + 1} 項修改缺少景點名稱。');
        return null;
      }

      if (widget.onResolvePlaceQuery == null) {
        _showMessage('尚未接上 AI 景點搜尋功能。');
        return null;
      }

      final excludedIds = {
        for (final constraint in _constraints) constraint.place.id,
        for (final place in _pendingPlaces) place.id,
        for (final place in resolvedPlaces.values) place.id,
      };

      List<ItineraryPlaceMatch> matches;

      try {
        matches = await widget.onResolvePlaceQuery!(query, excludedIds);
      } catch (error) {
        if (mounted) {
          _showMessage('搜尋「$query」時發生錯誤：$error');
        }
        return null;
      }

      if (!mounted) {
        return null;
      }

      if (matches.isEmpty) {
        _showMessage('找不到符合「$query」的景點。');
        return null;
      }

      final rankedMatches = _itineraryPlaceCandidateRanker
          .rank(
            matches: matches,
            itinerary: _itinerary,
            targetDay: command.targetDay,
          )
          .take(20)
          .toList();

      Place? selectedPlace;

      // 完全符合且沒有其他同分候選時，
      // 可以直接採用，仍會在修改預覽中顯示。
      final exactMatches = rankedMatches.where((match) {
        return match.reason.contains('景點名稱完全符合');
      }).toList();

      if (exactMatches.length == 1) {
        selectedPlace = exactMatches.first.place;
      } else {
        selectedPlace = await _showAiPlaceCandidateDialog(
          query: query,
          matches: rankedMatches,
        );
      }

      if (!mounted || selectedPlace == null) {
        return null;
      }

      resolvedPlaces[index] = selectedPlace;
    }

    return resolvedPlaces;
  }

  bool _isOutsidePreferredLocation(Place place) {
    final preferredLocation = _normalizeLocation(_itinerary.request.location);

    if (preferredLocation.isEmpty || preferredLocation == '全台') {
      return false;
    }

    final county = _normalizeLocation(PlaceService.countyFor(place));
    return county.isNotEmpty && county != preferredLocation;
  }

  String _normalizeLocation(String value) {
    return value.trim().replaceAll('臺', '台').replaceAll(RegExp(r'\s+'), '');
  }
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
