import 'package:flutter/material.dart';

import '../models/route_day.dart';
import '../models/route_itinerary.dart';
import '../widgets/day_itinerary_view.dart';
import '../widgets/trip_map_panel.dart';

class ItineraryResultPage extends StatefulWidget {
  final RouteItinerary itinerary;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;

  const ItineraryResultPage({
    super.key,
    required this.itinerary,
    this.onEdit,
    this.onExport,
  });

  @override
  State<ItineraryResultPage> createState() => _ItineraryResultPageState();
}

class _ItineraryResultPageState extends State<ItineraryResultPage> {
  int _selectedDayIndex = 0;
  bool _isMapVisible = false;
  double _mapHeightRatio = 0.42;

  RouteDay get _selectedDay => widget.itinerary.days[_selectedDayIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.itinerary.request.title.trim().isEmpty
              ? '行程規劃結果'
              : widget.itinerary.request.title,
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _isMapVisible = !_isMapVisible);
            },
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
      body: widget.itinerary.days.isEmpty
          ? const Center(child: Text('目前沒有可顯示的行程。'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = constraints.maxHeight * _mapHeightRatio;
                return Column(
                  children: [
                    _buildDaySelector(),
                    if (widget.itinerary.warnings.isNotEmpty)
                      _buildGeneralWarnings(),
                    if (_isMapVisible) ...[
                      SizedBox(
                        height: mapHeight,
                        child: TripMapPanel(day: _selectedDay),
                      ),
                      _buildResizeHandle(constraints.maxHeight),
                    ],
                    Expanded(child: DayItineraryView(day: _selectedDay)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        scrollDirection: Axis.horizontal,
        itemCount: widget.itinerary.days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = widget.itinerary.days[index];
          return ChoiceChip(
            selected: index == _selectedDayIndex,
            label: Text('Day ${day.day}'),
            onSelected: (_) {
              setState(() => _selectedDayIndex = index);
            },
          );
        },
      ),
    );
  }

  Widget _buildGeneralWarnings() {
    return MaterialBanner(
      content: Text(widget.itinerary.warnings.join('\n')),
      leading: const Icon(Icons.info_outline),
      actions: const [SizedBox.shrink()],
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
                  0.2,
                  0.7,
                );
          });
        },
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
      ),
    );
  }
}
