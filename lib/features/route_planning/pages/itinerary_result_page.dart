import 'dart:math';
import 'dart:async';
import '../models/compact_day_axis.dart';

import 'package:flutter/material.dart';
import '../../../widgets/trip/android_layout.dart';
import '../widgets/android_day_itinerary.dart';

import '../../../models/place.dart';
import '../../../models/trip_place_constraint.dart';
import '../../../models/visit_preferences.dart';
import '../../../services/live_itinerary_tracking_service.dart';
import '../../../services/location_service.dart';
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

class ItineraryResultPage extends StatefulWidget {
  final RouteItinerary itinerary;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final AddItineraryPlaces? onAddPlace;
  final RecalculateItinerary? onRecalculate;

  const ItineraryResultPage({
    super.key,
    required this.itinerary,
    this.onEdit,
    this.onExport,
    this.onAddPlace,
    this.onRecalculate,
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
  final _weatherAdvisoryService = WeatherAdvisoryService(
    apiKey: String.fromEnvironment('CWA_API_KEY'),
  );
  final _liveDayReplanner = LiveDayItineraryReplanner();

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
    final started = await _tripTracker.start(_itinerary);
    if (!mounted) return;
    if (!started) {
      _showMessage('無法取得 GPS 位置，請確認已開啟定位服務並允許位置權限。');
      return;
    }
    setState(() {
      _isTracking = true;
      _isMapVisible = true;
    });
    _showMessage('已開始 GPS 行程追蹤；若明顯延誤，系統會更新今天剩餘行程。');
  }

  Future<void> _stopTracking() async {
    await _tripTracker.stop();
    if (mounted) setState(() => _isTracking = false);
  }

  Future<void> _handleTrackingUpdate(TripTrackingUpdate update) async {
    if (!mounted) return;
    setState(() {
      _currentLocation = update.location;
      _trackedRoute = update.route;
    });
    await _weatherAdvisoryService.check(update.location);
    final alert = update.delayAlert;
    if (alert == null || _isLiveReplanning) return;

    final now = DateTime.now();
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
        generatedAt: DateTime.now(),
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
