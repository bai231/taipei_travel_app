import 'package:flutter/material.dart';

import '../models/place.dart';
import '../models/trip_request.dart';
import '../models/trip_place_constraint.dart';
import '../features/route_planning/models/route_place_input.dart';
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/pages/itinerary_result_page.dart';
import '../features/route_planning/services/itinerary_planning_service.dart';
import '../services/place_service.dart';
import '../widgets/trip/planner_item_picker.dart';

class TripPlannerPage extends StatefulWidget {
  final TripRequest request;
  final List<Place> places;

  const TripPlannerPage({
    super.key,
    required this.request,
    required this.places,
  });

  @override
  State<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<TripPlannerPage> {
  final ItineraryPlanningService _planningService = ItineraryPlanningService();

  // ============================================================
  // 使用者已經加入的景點
  // ============================================================

  final List<TripPlaceConstraint> _selectedPlaces = [];

  // ============================================================
  // 目前選擇的 Day
  // ============================================================

  int _selectedDay = 1;
  PlaceType _selectedType = PlaceType.attraction;
  bool _isGenerating = false;
  bool _isWaitingForTdx = false;
  String? _planningMessage;
  ItineraryPlanningControl? _planningControl;

  void _showPlacePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: PlannerItemPicker(
            type: _selectedType,
            places: widget.places,
            selectedPlaceIds: _selectedPlaces
                .map((item) => item.place.id)
                .toSet(),
            onConfirmed: (places) =>
                _replacePlacesForType(type: _selectedType, places: places),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("安排行程"),

        actions: [
          IconButton(
            icon: Icon(_typeIcon(_selectedType)),

            tooltip: "新增${_typeName(_selectedType)}",

            onPressed: _isGenerating ? null : _showPlacePicker,
          ),
        ],
      ),

      body: Column(
        children: [
          _buildTypeSelector(),

          // Day 選擇
          _buildDaySelector(),

          const Divider(height: 1),

          // 主要內容
          Expanded(child: _buildPlannerContent()),
        ],
      ),
      bottomNavigationBar: _buildGenerateBar(),
    );
  }

  Widget _buildGenerateBar() {
    final fixedTimeCount = _selectedPlaces
        .where((item) => item.day != null && item.startMinutes != null)
        .length;
    final fixedDayCount = _selectedPlaces
        .where((item) => item.day != null && item.startMinutes == null)
        .length;
    final automaticCount = _selectedPlaces
        .where((item) => item.day == null)
        .length;
    final attractionCount = _countSelected(PlaceType.attraction);
    final restaurantCount = _countSelected(PlaceType.restaurant);
    final accommodationCount = _countSelected(PlaceType.accommodation);

    return SafeArea(
      top: false,
      child: Material(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '景點 $attractionCount・餐廳 $restaurantCount・'
                '住宿 $accommodationCount｜固定時間 $fixedTimeCount・'
                '指定日期 $fixedDayCount・自動安排 $automaticCount',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _isGenerating ? null : _generateItinerary,
                icon: _isGenerating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.alt_route),
                label: Text(
                  _isGenerating
                      ? (_planningMessage ?? '正在安排詳細行程…')
                      : '完成安排，產生詳細行程',
                ),
              ),
              if (_isWaitingForTdx) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _useEstimatesForRemainingRoutes,
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('取消等待，後續改用估算'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Day 選擇器
  // ============================================================

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SegmentedButton<PlaceType>(
        segments: PlaceType.values
            .map(
              (type) => ButtonSegment<PlaceType>(
                value: type,
                icon: Icon(_typeIcon(type)),
                label: Text('安排${_typeName(type)}'),
              ),
            )
            .toList(),
        selected: {_selectedType},
        onSelectionChanged: _isGenerating
            ? null
            : (selection) {
                setState(() => _selectedType = selection.first);
              },
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 60,

      child: ListView.builder(
        scrollDirection: Axis.horizontal,

        itemCount: widget.request.days,

        itemBuilder: (context, index) {
          final day = index + 1;

          final isSelected = day == _selectedDay;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),

            child: ChoiceChip(
              label: Text("Day $day"),

              selected: isSelected,

              onSelected: (_) {
                setState(() {
                  _selectedDay = day;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // 主要規劃區域
  // ============================================================

  Widget _buildPlannerContent() {
    return Column(
      children: [
        // 時間軸
        Expanded(child: _buildTimeline()),

        const Divider(height: 1),

        // 不限日期 / 時間
        _buildUnscheduledArea(),
      ],
    );
  }

  // ============================================================
  // 時間軸
  // ============================================================

  Widget _buildTimeline() {
    final dayPlaces = _selectedPlaces
        .where((item) => item.day == _selectedDay)
        .toList();

    final timedPlaces = dayPlaces
        .where((item) => item.startMinutes != null)
        .toList();

    final untimedPlaces = dayPlaces
        .where((item) => item.startMinutes == null)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        // ==========================================
        // 已指定 Day，但還沒指定時間
        // ==========================================
        if (untimedPlaces.isNotEmpty) ...[
          const Text(
            "待安排時間",

            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          ...untimedPlaces.map((constraint) {
            return _buildUntimedPlaceCard(constraint);
          }),

          const SizedBox(height: 20),
        ],

        // ==========================================
        // 時間軸
        // ==========================================
        const Text(
          "時間軸",

          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        for (int hour = 9; hour <= 21; hour++)
          _buildTimeSlot(
            hour: hour,
            place: _findPlaceAtTime(timedPlaces, hour * 60),
          ),
      ],
    );
  }

  // ============================================================
  // 時間格
  // ============================================================

  Widget _buildTimeSlot({
    required int hour,
    required TripPlaceConstraint? place,
  }) {
    return SizedBox(
      height: 70,

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // 時間
          SizedBox(
            width: 55,

            child: Text(
              "${hour.toString().padLeft(2, '0')}:00",

              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 時間軸線
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 8),

              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),

              child: place == null
                  ? const SizedBox()
                  : _buildTimelinePlace(place),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 時間軸上的景點
  // ============================================================

  Widget _buildTimelinePlace(TripPlaceConstraint constraint) {
    return Container(
      margin: const EdgeInsets.only(top: 5, bottom: 5),

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),

        color: constraint.locked ? Colors.orange.shade100 : Colors.blue.shade50,

        border: Border.all(
          color: constraint.locked ? Colors.orange : Colors.blue,
        ),
      ),

      child: Row(
        children: [
          Icon(
            constraint.locked ? Icons.lock : _typeIcon(constraint.place.type),
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              constraint.place.name,

              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          if (constraint.startMinutes != null)
            Text(_formatTime(constraint.startMinutes!)),
        ],
      ),
    );
  }

  // ============================================================
  // 找某個時間點的景點
  // ============================================================

  TripPlaceConstraint? _findPlaceAtTime(
    List<TripPlaceConstraint> places,
    int startMinutes,
  ) {
    for (final constraint in places) {
      if (constraint.startMinutes == null) {
        continue;
      }

      final placeStart = constraint.startMinutes!;

      final placeEnd = placeStart + constraint.place.stayTime;

      if (startMinutes >= placeStart && startMinutes < placeEnd) {
        return constraint;
      }
    }

    return null;
  }

  // ============================================================
  // 不限日期 / 時間區域
  // ============================================================

  Widget _buildUnscheduledArea() {
    final unscheduledPlaces = _selectedPlaces
        .where(
          (item) =>
              item.day == null &&
              item.startMinutes == null &&
              item.place.type == _selectedType,
        )
        .toList();

    return Container(
      width: double.infinity,

      constraints: const BoxConstraints(minHeight: 150, maxHeight: 230),

      padding: const EdgeInsets.all(12),

      color: Colors.grey.shade100,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(_typeIcon(_selectedType)),

              const SizedBox(width: 8),

              Text(
                "不限日期／時間的${_typeName(_selectedType)}",

                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            "這些${_typeName(_selectedType)}會由系統自動安排",

            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: unscheduledPlaces.isEmpty
                ? Center(
                    child: Text(
                      "目前沒有待安排${_typeName(_selectedType)}",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,

                    itemCount: unscheduledPlaces.length,

                    itemBuilder: (context, index) {
                      return _buildUnscheduledCard(unscheduledPlaces[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 不限時間景點 Card
  // ============================================================

  Widget _buildUnscheduledCard(TripPlaceConstraint constraint) {
    return Container(
      width: 190,

      margin: const EdgeInsets.only(right: 10),

      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      constraint.place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '移除${_typeName(constraint.place.type)}',
                    onPressed: _isGenerating
                        ? null
                        : () => _removePlace(constraint),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 狀態
              Text(
                _getConstraintStatus(constraint),

                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),

              const Spacer(),

              // 指定日期
              SizedBox(
                width: double.infinity,

                child: OutlinedButton(
                  onPressed: () {
                    _selectDay(constraint);
                  },

                  child: const Text("指定日期"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 指定天數、不限時間 Card
  // ============================================================
  Widget _buildUntimedPlaceCard(TripPlaceConstraint constraint) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Row(
          children: [
            Icon(_typeIcon(constraint.place.type)),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    constraint.place.name,

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Day ${constraint.day}・時間不限",

                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),

            OutlinedButton(
              onPressed: () {
                _selectTime(constraint);
              },

              child: const Text("指定時間"),
            ),

            IconButton(
              tooltip: '移除${_typeName(constraint.place.type)}',
              onPressed: _isGenerating ? null : () => _removePlace(constraint),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  String _getConstraintStatus(TripPlaceConstraint constraint) {
    if (constraint.day == null) {
      return "不限日期／時間";
    }

    if (constraint.startMinutes == null) {
      return "Day ${constraint.day}・時間不限";
    }

    if (constraint.locked) {
      return "Day ${constraint.day}・"
          "${_formatTime(constraint.startMinutes!)}・已鎖定";
    }

    return "Day ${constraint.day}・"
        "${_formatTime(constraint.startMinutes!)}";
  }

  void _selectDay(TripPlaceConstraint constraint) {
    showModalBottomSheet(
      context: context,

      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Padding(
                padding: EdgeInsets.all(16),

                child: Text(
                  "選擇日期",

                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              for (int day = 1; day <= widget.request.days; day++)
                ListTile(
                  leading: const Icon(Icons.calendar_today),

                  title: Text("Day $day"),

                  trailing: constraint.day == day
                      ? const Icon(Icons.check)
                      : null,

                  onTap: () {
                    setState(() {
                      constraint.day = day;
                    });

                    Navigator.pop(context);
                  },
                ),

              // 清除日期
              ListTile(
                leading: const Icon(Icons.clear),

                title: const Text("不限日期"),

                onTap: () {
                  setState(() {
                    constraint.day = null;

                    // 如果取消 Day，
                    // 時間也必須清除
                    constraint.startMinutes = null;

                    constraint.locked = false;
                  });

                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTime(TripPlaceConstraint constraint) async {
    // 沒有指定 Day 就不能指定時間
    if (constraint.day == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先指定日期")));

      return;
    }

    final initialTime = constraint.startMinutes != null
        ? TimeOfDay(
            hour: constraint.startMinutes! ~/ 60,

            minute: constraint.startMinutes! % 60,
          )
        : const TimeOfDay(hour: 9, minute: 0);

    final TimeOfDay? result = await showTimePicker(
      context: context,

      initialTime: initialTime,
    );

    if (result == null || !mounted) {
      return;
    }

    // 計算這個 Day 對應的實際日期。
    final selectedDate = DateTime(
      widget.request.startDate.year,
      widget.request.startDate.month,
      widget.request.startDate.day + constraint.day! - 1,
    );

    // 將使用者選擇的日期與時間組合起來。
    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      result.hour,
      result.minute,
    );

    final now = DateTime.now();

    // 目前排程以分鐘為單位，因此去除秒數後再加一分鐘。
    final minimumDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));

    if (selectedDateTime.isBefore(minimumDateTime)) {
      final selectedDayOnly = DateTime(
        selectedDateTime.year,
        selectedDateTime.month,
        selectedDateTime.day,
      );

      final todayOnly = DateTime(now.year, now.month, now.day);

      final message = selectedDayOnly.isBefore(todayOnly)
          ? '不能將景點安排在已經過去的日期。'
          : '今天的景點最早只能安排在 ${_formatTime(minimumDateTime.hour * 60 + minimumDateTime.minute)}。';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      return;
    }

    setState(() {
      constraint.startMinutes = result.hour * 60 + result.minute;
      constraint.locked = true;
    });
  }

  Future<List<Place>> _pickAdditionalPlaces(
    BuildContext resultContext,
    Set<String> selectedPlaceIds,
  ) async {
    // 先選擇要新增的種類
    final selectedType = await showModalBottomSheet<PlaceType>(
      context: resultContext,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '選擇新增項目類型',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              for (final type in PlaceType.values)
                ListTile(
                  leading: Icon(_typeIcon(type)),
                  title: Text(_typeName(type)),
                  onTap: () => Navigator.pop(context, type),
                ),
            ],
          ),
        );
      },
    );

    if (selectedType == null || !mounted) {
      return <Place>[];
    }

    var addedPlaces = <Place>[];

    // 再開啟原本的景點選擇器
    await showModalBottomSheet<void>(
      context: resultContext,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: PlannerItemPicker(
            type: selectedType,
            places: widget.places,
            selectedPlaceIds: selectedPlaceIds,
            onConfirmed: (places) {
              // PlannerItemPicker 回傳的是該種類目前所有已勾選項目，
              // 這裡只保留尚未存在於行程中的新景點。
              addedPlaces = places
                  .where((place) => !selectedPlaceIds.contains(place.id))
                  .toList();
            },
          ),
        );
      },
    );

    return addedPlaces;
  }

  Future<RouteItinerary> _recalculateItinerary(
    List<TripPlaceConstraint> constraints,
  ) async {
    if (constraints.isEmpty) {
      throw StateError('行程中至少需要保留一個景點。');
    }

    final invalidPlaces = constraints
        .where(
          (constraint) => !PlaceService.hasUsableCoordinates(constraint.place),
        )
        .map((constraint) => constraint.place.name)
        .toList();

    if (invalidPlaces.isNotEmpty) {
      throw StateError('以下行程項目缺少有效座標：${invalidPlaces.join('、')}');
    }

    final routeInputs = constraints
        .map(
          (constraint) => RoutePlaceInput(
            place: constraint.place,
            day: constraint.day,
            startMinutes: constraint.startMinutes,
            locked: constraint.locked,
          ),
        )
        .toList();

    return _planningService.generate(
      request: widget.request,
      places: routeInputs,
    );
  }

  Future<void> _generateItinerary() async {
    if (_selectedPlaces.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少加入一個行程項目')));
      return;
    }

    final invalidPlaces = _selectedPlaces
        .where(
          (constraint) => !PlaceService.hasUsableCoordinates(constraint.place),
        )
        .map((constraint) => constraint.place.name)
        .toList();
    if (invalidPlaces.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '以下行程項目缺少有效座標：${invalidPlaces.join('、')}。'
            '請移除後重新產生行程。',
          ),
        ),
      );
      return;
    }

    final planningControl = ItineraryPlanningControl();
    setState(() {
      _isGenerating = true;
      _isWaitingForTdx = false;
      _planningMessage = '正在整理景點限制…';
      _planningControl = planningControl;
    });

    try {
      final itinerary = await _planningService.generate(
        request: widget.request,
        places: _selectedPlaces
            .map(
              (constraint) => RoutePlaceInput(
                place: constraint.place,
                day: constraint.day,
                startMinutes: constraint.startMinutes,
                locked: constraint.locked,
              ),
            )
            .toList(),
        onProgress: (message) {
          if (!mounted) return;
          setState(() => _planningMessage = message);
        },
        onRateLimitWait: (remaining) {
          if (!mounted) return;
          setState(() => _isWaitingForTdx = remaining != null);
        },
        control: planningControl,
      );
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _isWaitingForTdx = false;
        _planningMessage = null;
        _planningControl = null;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (resultContext) => ItineraryResultPage(
            itinerary: itinerary,
            onEdit: () => Navigator.of(resultContext).pop(),
            onAddPlace: _pickAdditionalPlaces,
            onRecalculate: _recalculateItinerary,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法產生詳細行程：$error')));
    } finally {
      if (mounted && _isGenerating) {
        setState(() {
          _isGenerating = false;
          _isWaitingForTdx = false;
          _planningMessage = null;
          _planningControl = null;
        });
      }
    }
  }

  void _useEstimatesForRemainingRoutes() {
    _planningControl?.useEstimates();
    setState(() {
      _isWaitingForTdx = false;
      _planningMessage = '已取消 TDX 等待，正在以估計時間完成行程…';
    });
  }

  void _replacePlacesForType({
    required PlaceType type,
    required List<Place> places,
  }) {
    final selectedIds = places.map((place) => place.id).toSet();
    setState(() {
      _selectedPlaces.removeWhere(
        (constraint) =>
            constraint.place.type == type &&
            !selectedIds.contains(constraint.place.id),
      );
      final existingIds = _selectedPlaces
          .map((constraint) => constraint.place.id)
          .toSet();
      for (final place in places) {
        if (existingIds.add(place.id)) {
          _selectedPlaces.add(
            TripPlaceConstraint(place: place, day: null, startMinutes: null),
          );
        }
      }
    });
  }

  // ============================================================
  // 移除景點
  // ============================================================

  void _removePlace(TripPlaceConstraint constraint) {
    setState(() {
      _selectedPlaces.remove(constraint);
    });
  }

  int _countSelected(PlaceType type) {
    return _selectedPlaces.where((item) => item.place.type == type).length;
  }

  String _typeName(PlaceType type) {
    return switch (type) {
      PlaceType.attraction => '景點',
      PlaceType.restaurant => '餐廳',
      PlaceType.accommodation => '住宿',
    };
  }

  IconData _typeIcon(PlaceType type) {
    return switch (type) {
      PlaceType.attraction => Icons.attractions,
      PlaceType.restaurant => Icons.restaurant,
      PlaceType.accommodation => Icons.hotel,
    };
  }

  // ============================================================
  // 時間格式
  // ============================================================

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return "${hour.toString().padLeft(2, '0')}:"
        "${minute.toString().padLeft(2, '0')}";
  }
}
