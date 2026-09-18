import 'package:flutter/material.dart';
import '../models/recommendation_criteria.dart';
import '../services/recommendation/recommendation_criteria_factory.dart';
import '../models/place_recommendation.dart';
import '../services/recommendation/place_recommendation_service.dart';
import 'dart:convert';
import '../models/place.dart';
import '../models/trip_request.dart';
import '../models/trip_place_constraint.dart';
import '../features/route_planning/models/route_place_input.dart';
import '../features/route_planning/models/route_travel_mode.dart';
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/pages/itinerary_result_page.dart';
import '../features/route_planning/services/itinerary_planning_service.dart';
import '../services/place_service.dart';
import '../widgets/trip/cloud_planner_item_picker.dart';
import '../widgets/trip/visit_preferences_dialog.dart';
import '../services/recommendation/recommendation_candidate_filter.dart';
import '../models/must_visit_resolution.dart';
import '../services/recommendation/must_visit_resolver.dart';

class TripPlannerPage extends StatefulWidget {
  final TripRequest request;
  final List<Place> places;

  /// Precomputed display scores for attraction/restaurant/accommodation pickers.
  final Map<String, num> candidateScoresByPlaceId;

  const TripPlannerPage({
    super.key,
    required this.request,
    required this.places,
    this.candidateScoresByPlaceId = const {},
  });

  @override
  State<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<TripPlannerPage> {
  late final RecommendationCriteria _recommendationCriteria;
  late final List<Place> _candidatePlaces;
  late final int _allAttractionCount;
  late final List<PlaceRecommendation> _recommendations;
  late final MustVisitResolution _mustVisitResolution;
  final ItineraryPlanningService _planningService = ItineraryPlanningService();
  late final Set<String> _mustVisitPlaceIds;
  late final Set<String> _conflictingMustVisitPlaceIds;

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
          child: CloudPlannerItemPicker(
            type: _selectedType,
            places: widget.places,
            candidateScoresByPlaceId: widget.candidateScoresByPlaceId,
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
  void initState() {
    super.initState();

    _recommendationCriteria = RecommendationCriteriaFactory.fromTripRequest(
      widget.request,
    );

    final allAttractions = widget.places
        .where((place) => place.type == PlaceType.attraction)
        .toList();

    _allAttractionCount = allAttractions.length;

    _candidatePlaces = RecommendationCandidateFilter.filter(
      places: allAttractions,
      criteria: _recommendationCriteria,
    );

    _recommendations = PlaceRecommendationService().rank(
      candidates: _candidatePlaces,
      criteria: _recommendationCriteria,
    );

    _mustVisitResolution = MustVisitResolver().resolve(
      criteria: _recommendationCriteria,
      places: widget.places,
    );

    final addableConflictingPlaces = _mustVisitResolution.conflictingPlaces
        .where(PlaceService.hasUsableCoordinates)
        .toList();

    final autoAddedMustVisitPlaces = [
      ..._mustVisitResolution.matchedPlaces,
      ...addableConflictingPlaces,
    ];

    _mustVisitPlaceIds = autoAddedMustVisitPlaces
        .map((place) => place.id)
        .toSet();

    _conflictingMustVisitPlaceIds = addableConflictingPlaces
        .map((place) => place.id)
        .toSet();

    final existingIds = _selectedPlaces
        .map((constraint) => constraint.place.id)
        .toSet();

    for (final place in autoAddedMustVisitPlaces) {
      if (existingIds.add(place.id)) {
        _selectedPlaces.add(
          TripPlaceConstraint(
            place: place,
            day: null,
            startMinutes: null,
            locked: false,
          ),
        );
      }
    }
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
          // 手動輸入prompt需求
          //_buildAiPreferenceCard(),

          // 推薦條件
          //_buildRecommendationCriteriaCard(),

          //顯示篩選
          //_buildCandidateFilterCard(),
          _buildMustVisitResultCard(),

          //顯示推薦結果
          _buildRecommendationResultCard(),

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

  //測試用
  Widget _buildAiPreferenceCard() {
    final preference = widget.request.parsedPreference;

    // 使用者沒有輸入 AI 偏好時，不顯示卡片。
    if (preference == null) {
      return const SizedBox.shrink();
    }

    final prettyJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(preference.toJson());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text(
            'AI 已理解你的旅遊需求',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: preference.summary.isNotEmpty
              ? Text(
                  preference.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : const Text('點擊查看解析結果'),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  prettyJson,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCriteriaCard() {
    final prettyJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(_recommendationCriteria.toJson());

    final categoryCount = _recommendationCriteria.preferredCategories.length;

    final tagCount = _recommendationCriteria.preferredTags.length;

    final excludedCount =
        _recommendationCriteria.excludedCategories.length +
        _recommendationCriteria.excludedTags.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.tune),
          title: const Text(
            '已整合的推薦條件',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '分類 $categoryCount 個・'
            '標籤 $tagCount 個・'
            '排除條件 $excludedCount 個',
          ),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  prettyJson,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateFilterCard() {
    final removedCount = _allAttractionCount - _candidatePlaces.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.filter_alt),
          title: const Text(
            '景點候選過濾結果',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '$_allAttractionCount 個景點'
            ' → ${_candidatePlaces.length} 個候選'
            '・排除 $removedCount 個',
          ),
          children: [
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '地區：${_recommendationCriteria.location}\n'
                  '最高價格等級：'
                  '${_recommendationCriteria.budgetLevel}',
                ),
              ),
            ),

            if (_candidatePlaces.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '沒有符合目前條件的景點，'
                  '可能需要放寬地區、預算或排除條件。',
                  style: TextStyle(color: Colors.orange),
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '前 10 個候選景點：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              ..._candidatePlaces.take(10).map((place) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 20),
                  title: Text(place.name),
                  subtitle: Text(
                    '${place.category}'
                    '・價格等級 ${place.price_level}',
                  ),
                );
              }),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationResultCard() {
    final removedCount = _allAttractionCount - _candidatePlaces.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.recommend),
          title: const Text(
            '景點推薦結果',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_candidatePlaces.length} 個候選'
            '・排除 $removedCount 個'
            '・依適合程度排序',
          ),
          children: [
            const Divider(height: 1),

            if (_recommendations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '目前沒有符合條件的推薦景點。',
                  style: TextStyle(color: Colors.orange),
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '前 10 名推薦景點',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              ..._recommendations.take(10).toList().asMap().entries.map((
                entry,
              ) {
                final rank = entry.key + 1;
                final recommendation = entry.value;
                final place = recommendation.place;

                return ListTile(
                  isThreeLine: true,
                  leading: CircleAvatar(child: Text('$rank')),
                  title: Text(place.name),
                  subtitle: Text(
                    '${place.category}\n'
                    '${recommendation.reasons.join('・')}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        recommendation.totalScore.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text('分', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMustVisitResultCard() {
    if (_recommendationCriteria.mustVisitPlaceNames.isEmpty) {
      return const SizedBox.shrink();
    }

    final matchedCount = _mustVisitResolution.matchedPlaces.length;

    final conflictCount = _mustVisitResolution.conflictingPlaces.length;

    final unmatchedCount = _mustVisitResolution.unmatchedNames.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.push_pin),
          title: const Text(
            '必去景點確認',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '找到 $matchedCount 個・'
            '衝突 $conflictCount 個・'
            '找不到 $unmatchedCount 個',
          ),
          children: [
            const Divider(height: 1),

            if (_mustVisitResolution.matchedPlaces.isNotEmpty) ...[
              const _ResultSectionTitle(title: '成功找到', color: Colors.green),
              ..._mustVisitResolution.matchedPlaces.map((place) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(place.name),
                  subtitle: Text(
                    '${place.category}・'
                    '${PlaceService.countyFor(place)}',
                  ),
                );
              }),
            ],

            if (_mustVisitResolution.conflictingPlaces.isNotEmpty) ...[
              const _ResultSectionTitle(title: '與目前條件衝突', color: Colors.red),
              ..._mustVisitResolution.conflictingPlaces.map((place) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber, color: Colors.red),
                  title: Text(place.name),
                  subtitle: Text(
                    '${place.category}・'
                    '${PlaceService.countyFor(place)}\n'
                    '可能與縣市、預算或排除條件衝突',
                  ),
                );
              }),
            ],

            if (_mustVisitResolution.unmatchedNames.isNotEmpty) ...[
              const _ResultSectionTitle(title: '資料庫找不到', color: Colors.orange),
              ..._mustVisitResolution.unmatchedNames.map((name) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.help_outline, color: Colors.orange),
                  title: Text(name),
                  subtitle: const Text('請確認景點名稱，或稍後手動搜尋'),
                );
              }),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
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

        for (int hour = 0; hour <= 23; hour++)
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
          _preferencesButton(constraint),
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

      final placeEnd = placeStart + constraint.stayMinutes;

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

      constraints: const BoxConstraints(minHeight: 150, maxHeight: 280),

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
                '${_getConstraintStatus(constraint)}\n${constraint.preferences.summaryFor(constraint.place)}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,

                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),

              if (_conflictingMustVisitPlaceIds.contains(
                constraint.place.id,
              )) ...[
                const SizedBox(height: 4),
                Text(
                  '提醒：此景點並非預設遊玩範圍，'
                  '但因為是必去景點仍會保留。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const Spacer(),

              // 指定日期
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isGenerating
                          ? null
                          : () => _selectDay(constraint),
                      child: Text(
                        constraint.place.type == PlaceType.accommodation
                            ? '調整住宿'
                            : '指定日期',
                      ),
                    ),
                  ),
                  _preferencesButton(constraint),
                ],
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
                    'Day ${constraint.day}・時間不限\n${constraint.preferences.summaryFor(constraint.place)}',

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

            _preferencesButton(constraint),

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

  Widget _preferencesButton(TripPlaceConstraint constraint) {
    return IconButton(
      tooltip: '時段、停留與資訊來源',
      onPressed: _isGenerating ? null : () => _editPreferences(constraint),
      icon: const Icon(Icons.tune, size: 20),
    );
  }

  Future<void> _editPreferences(TripPlaceConstraint constraint) async {
    final preferences = await showVisitPreferencesDialog(
      context: context,
      place: constraint.place,
      request: widget.request,
      initial: constraint.preferences,
      day: constraint.day,
    );
    if (!mounted || preferences == null) return;
    setState(() {
      constraint.preferences = preferences;
      if (preferences.hotelStay != null) {
        constraint.day = preferences.hotelStay!.checkInDay;
      }
    });
  }

  void _selectDay(TripPlaceConstraint constraint) {
    if (constraint.place.type == PlaceType.accommodation) {
      _editPreferences(constraint);
      return;
    }
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
        : const TimeOfDay(hour: 0, minute: 0);

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
          child: CloudPlannerItemPicker(
            type: selectedType,
            places: widget.places,
            candidateScoresByPlaceId: widget.candidateScoresByPlaceId,
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
    Map<RouteLegKey, RouteTravelMode> travelModeOverrides,
    RouteItinerary previousItinerary,
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
            preferences: constraint.preferences,
            day: constraint.day,
            startMinutes: constraint.startMinutes,
            locked: constraint.locked,
          ),
        )
        .toList();

    final result = await _planningService.generate(
      request: widget.request,
      places: routeInputs,
      travelModeOverrides: travelModeOverrides,
      reusableItinerary: previousItinerary,
    );
    if (mounted) {
      setState(() {
        _selectedPlaces
          ..clear()
          ..addAll(
            constraints.map(
              (item) => TripPlaceConstraint(
                place: item.place,
                day: item.day,
                startMinutes: item.startMinutes,
                locked: item.locked,
                preferences: item.preferences,
              ),
            ),
          );
      });
    }
    return result;
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
                preferences: constraint.preferences,
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
            !selectedIds.contains(constraint.place.id) &&
            !_mustVisitPlaceIds.contains(constraint.place.id),
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
    if (_mustVisitPlaceIds.contains(constraint.place.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${constraint.place.name} 是必去景點，'
            '若要移除，請返回修改旅遊需求。',
          ),
        ),
      );

      return;
    }

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

class _ResultSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _ResultSectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
