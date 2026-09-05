import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/place.dart';
import '../../../models/trip_place_constraint.dart';
import '../../../models/visit_preferences.dart';
import '../../../widgets/trip/visit_preferences_dialog.dart';
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
  static const _dayWidth = 280.0;
  static const _timeWidth = 64.0;
  static const _hourHeight = 92.0;
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();
  final List<Place> _pendingPlaces = [];

  late RouteItinerary _itinerary;
  late List<TripPlaceConstraint> _constraints;
  late Map<RouteLegKey, RouteTravelMode> _travelModeOverrides;
  int _selectedDayIndex = 0;
  bool _isMapVisible = false;
  bool _isRecalculating = false;
  double _mapHeightRatio = 0.34;

  RouteDay get _selectedDay => _itinerary.days[_selectedDayIndex];

  @override
  void initState() {
    super.initState();
    _itinerary = widget.itinerary;
    _constraints = _constraintsFromItinerary(_itinerary);
    _travelModeOverrides = Map.of(_itinerary.travelModeOverrides);
  }

  @override
  void didUpdateWidget(covariant ItineraryResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itinerary, widget.itinerary)) {
      _itinerary = widget.itinerary;
      _constraints = _constraintsFromItinerary(_itinerary);
      _travelModeOverrides = Map.of(_itinerary.travelModeOverrides);
      _selectedDayIndex = min(
        _selectedDayIndex,
        max(0, _itinerary.days.length - 1),
      );
    }
  }

  @override
  void dispose() {
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
          TextButton.icon(
            onPressed: _itinerary.days.isEmpty
                ? null
                : () => setState(() => _isMapVisible = !_isMapVisible),
            icon: Icon(_isMapVisible ? Icons.map_outlined : Icons.map),
            label: Text(_isMapVisible ? '隱藏地圖' : '顯示地圖'),
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
                    SizedBox(
                      height: constraints.maxHeight * _mapHeightRatio,
                      child: TripMapPanel(day: _selectedDay),
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
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: _isRecalculating ? null : _addPlace,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('新增景點'),
          ),
          const SizedBox(width: 12),
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
        _constraints = _constraintsFromItinerary(result);
        _travelModeOverrides = Map.of(result.travelModeOverrides);
        _selectedDayIndex = min(
          _selectedDayIndex,
          max(0, result.days.length - 1),
        );
      });
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

  bool _containsPlace(String id) {
    return _constraints.any((item) => item.place.id == id) ||
        _pendingPlaces.any((item) => item.id == id);
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
