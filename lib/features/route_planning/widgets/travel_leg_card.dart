import 'package:flutter/material.dart';

import '../../../models/tdx_route.dart';
import '../models/travel_leg.dart';

class TravelLegCard extends StatelessWidget {
  final TravelLeg leg;

  const TravelLegCard({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    final route = leg.route;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: route == null
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        leading: Icon(route == null ? Icons.warning_amber : Icons.directions),
        title: Text('${leg.origin.name} → ${leg.destination.name}'),
        subtitle: Text(_summary()),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (leg.errorMessage != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                leg.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (route != null && route.sections.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('TDX 沒有提供更細的路段資訊。'),
            ),
          if (route != null)
            ...route.sections.asMap().entries.map(
              (entry) => _RouteSectionTile(
                index: entry.key,
                section: entry.value,
              ),
            ),
        ],
      ),
    );
  }

  String _summary() {
    final departure = _formatMinutes(leg.schedule.departureMinutes);
    final arrival = _formatMinutes(leg.schedule.arrivalMinutes);
    final duration =
        leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
    final source = leg.usesEstimatedTravelTime ? '估計' : 'TDX';
    return '$departure 出發・$arrival 抵達・$source 約 $duration 分鐘';
  }
}

class _RouteSectionTile extends StatelessWidget {
  final int index;
  final RouteSection section;

  const _RouteSectionTile({required this.index, required this.section});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (section.departureTime != null) '${section.departureTime} 出發',
      if (section.arrivalTime != null) '${section.arrivalTime} 抵達',
      if (section.travelTime > 0)
        '約 ${(section.travelTime / 60).ceil()} 分鐘',
      if (section.stopCount > 0) '${section.stopCount} 站',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 15,
        child: Text('${index + 1}'),
      ),
      title: Text(_sectionTitle(section)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty) Text(details.join('・')),
          if (section.departureTitle != null || section.arrivalTitle != null)
            Text(
              '${section.departureTitle ?? '起點'} → '
              '${section.arrivalTitle ?? '終點'}',
            ),
          if (section.intermediateStops.isNotEmpty)
            Text('途經：${section.intermediateStops.join('、')}'),
        ],
      ),
    );
  }

  String _sectionTitle(RouteSection section) {
    final mode = _modeLabel(section.mode);
    final line = section.lineName;
    final destination = section.destination;
    return [
      mode,
      if (line != null && line.isNotEmpty) line,
      if (destination != null && destination.isNotEmpty) '往 $destination',
    ].join('・');
  }

  String _modeLabel(String mode) {
    switch (mode.toLowerCase()) {
      case 'pedestrian':
      case 'walk':
      case 'walking':
        return '步行';
      case 'bus':
        return '公車';
      case 'metro':
      case 'subway':
        return '捷運';
      case 'train':
      case 'rail':
        return '火車';
      case 'bike':
      case 'cycle':
        return '自行車';
      case 'drive':
      case 'car':
        return '開車';
      case 'transit':
        return '大眾運輸';
      default:
        return mode;
    }
  }
}

String _formatMinutes(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
