import 'package:flutter/material.dart';

import '../models/place.dart';
import '../models/trip_request.dart';
import '../models/trip_place_constraint.dart';
import '../features/route_planning/models/route_place_input.dart';
import '../features/route_planning/pages/itinerary_result_page.dart';
import '../features/route_planning/services/itinerary_planning_service.dart';

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
  bool _isGenerating = false;
  String? _planningMessage;

  void _showPlacePicker() {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,

          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),

                child: Text(
                  "選擇景點",

                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              const Divider(),

              Expanded(
                child: ListView.builder(
                  itemCount: widget.places.length,

                  itemBuilder: (context, index) {
                    final place = widget.places[index];

                    final alreadyAdded = _selectedPlaces.any(
                      (item) => item.place.id == place.id,
                    );

                    return ListTile(
                      leading: const Icon(Icons.place),

                      title: Text(place.name),

                      subtitle: Text(
                        "⭐ ${place.rating}   "
                        "停留 ${place.stayTime} 分鐘",
                      ),

                      trailing: IconButton(
                        icon: Icon(alreadyAdded ? Icons.check : Icons.add),

                        onPressed: alreadyAdded
                            ? null
                            : () {
                                _addPlace(place);

                                Navigator.pop(context);
                              },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("安排景點"),

        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),

            tooltip: "新增景點",

            onPressed: _isGenerating ? null : _showPlacePicker,
          ),
        ],
      ),

      body: Column(
        children: [
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
                '已選 ${_selectedPlaces.length} 個景點・'
                '固定時間 $fixedTimeCount・'
                '指定日期 $fixedDayCount・'
                '自動安排 $automaticCount',
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
                      : '完成景點安排，產生詳細行程',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Day 選擇器
  // ============================================================

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
          Icon(constraint.locked ? Icons.lock : Icons.place, size: 18),

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
        .where((item) => item.day == null && item.startMinutes == null)
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
              const Icon(Icons.inbox_outlined),

              const SizedBox(width: 8),

              const Text(
                "不限日期／時間",

                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            "這些景點會由系統自動安排",

            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: unscheduledPlaces.isEmpty
                ? Center(
                    child: Text(
                      "目前沒有待安排景點",
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
                    tooltip: '移除景點',
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
            const Icon(Icons.schedule),

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
              tooltip: '移除景點',
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

    if (result == null) {
      return;
    }

    setState(() {
      constraint.startMinutes = result.hour * 60 + result.minute;
      constraint.locked = true;
    });
  }

  Future<void> _generateItinerary() async {
    if (_selectedPlaces.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少加入一個景點')));
      return;
    }

    setState(() {
      _isGenerating = true;
      _planningMessage = '正在整理景點限制…';
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
      );
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _planningMessage = null;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (resultContext) => ItineraryResultPage(
            itinerary: itinerary,
            onEdit: () => Navigator.of(resultContext).pop(),
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
          _planningMessage = null;
        });
      }
    }
  }

  // ============================================================
  // 加入景點
  // ============================================================

  void _addPlace(Place place) {
    setState(() {
      _selectedPlaces.add(
        TripPlaceConstraint(place: place, day: null, startMinutes: null),
      );
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
