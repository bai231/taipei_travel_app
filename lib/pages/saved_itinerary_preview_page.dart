import 'package:flutter/material.dart';

import '../features/route_planning/models/route_day.dart';
import '../features/route_planning/models/route_itinerary.dart';
import '../features/route_planning/models/route_visit.dart';
import '../features/route_planning/models/travel_leg.dart';
import '../theme/app_colors.dart';

/// A read-only view of the itinerary exactly as it was saved. Editing and
/// saving belong to the result page reached through [onEdit].
class SavedItineraryPreviewPage extends StatefulWidget {
  const SavedItineraryPreviewPage({
    super.key,
    required this.itinerary,
    required this.onEdit,
  });

  final RouteItinerary itinerary;
  final VoidCallback onEdit;

  @override
  State<SavedItineraryPreviewPage> createState() =>
      _SavedItineraryPreviewPageState();
}

class _SavedItineraryPreviewPageState extends State<SavedItineraryPreviewPage> {
  final Set<String> _expandedReasons = {};

  @override
  Widget build(BuildContext context) {
    final title = widget.itinerary.request.title.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title.isEmpty ? '我的行程' : title),
        actions: [
          TextButton.icon(
            key: const ValueKey('open-editable-itinerary'),
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('修改'),
          ),
        ],
      ),
      body: widget.itinerary.days.isEmpty
          ? const Center(child: Text('查無行程內容'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = (constraints.maxWidth - 32).clamp(
                  240.0,
                  340.0,
                );
                return ListView.separated(
                  key: const ValueKey('saved-itinerary-day-list'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.itinerary.days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) => SizedBox(
                    width: columnWidth,
                    child: _dayColumn(widget.itinerary.days[index]),
                  ),
                );
              },
            ),
    );
  }

  Widget _dayColumn(RouteDay day) {
    final date = day.date;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day ${day.day}・${date.month}/${date.day}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: day.visits.isEmpty
                  ? const Center(child: Text('當天沒有行程項目'))
                  : ListView.builder(
                      itemCount: day.visits.length,
                      itemBuilder: (context, index) {
                        final visit = day.visits[index];
                        final incomingLeg = index < day.travelLegs.length
                            ? day.travelLegs[index]
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (incomingLeg != null)
                              _travelSummary(incomingLeg),
                            _visitCard(day, visit, index),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _travelSummary(TravelLeg leg) {
    final duration =
        leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.alt_route, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${leg.travelMode.label}・${duration < 0 ? 0 : duration} 分鐘'
              '・${leg.routeSourceLabel}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitCard(RouteDay day, RouteVisit visit, int index) {
    final reason = visit.information.join('、').trim();
    final key = '${day.day}:${visit.occurrenceId}:$index';
    final expanded = _expandedReasons.contains(key);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_time(visit.startMinutes)}–${_time(visit.endMinutes)}',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              visit.label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '停留 ${visit.stayMinutes} 分鐘',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(() {
                  if (expanded) {
                    _expandedReasons.remove(key);
                  } else {
                    _expandedReasons.add(key);
                  }
                }),
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(expanded ? '收起推薦理由' : '查看推薦理由'),
              ),
              if (expanded)
                Text(
                  reason,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _time(int minutes) {
    final normalized = minutes % 1440;
    final hours = (normalized ~/ 60).toString().padLeft(2, '0');
    final mins = (normalized % 60).toString().padLeft(2, '0');
    return '$hours:$mins${minutes >= 1440 ? '＋${minutes ~/ 1440}日' : ''}';
  }
}
