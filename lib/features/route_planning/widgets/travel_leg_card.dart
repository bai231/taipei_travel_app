import 'package:flutter/material.dart';

import '../../../models/tdx_route.dart';
import '../../../services/google_maps_navigation_service.dart';
import '../models/travel_leg.dart';

class TravelLegCard extends StatefulWidget {
  final TravelLeg leg;

  const TravelLegCard({super.key, required this.leg});

  @override
  State<TravelLegCard> createState() => _TravelLegCardState();
}

class _TravelLegCardState extends State<TravelLegCard> {
  final GoogleMapsNavigationService _navigationService =
      GoogleMapsNavigationService();
  bool _isOpeningNavigation = false;

  @override
  Widget build(BuildContext context) {
    final leg = widget.leg;
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
              (entry) =>
                  _RouteSectionTile(index: entry.key, section: entry.value),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isOpeningNavigation ? null : _openNavigation,
              icon: _isOpeningNavigation
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.navigation_outlined),
              label: const Text('在 Google Maps 導航'),
            ),
          ),
        ],
      ),
    );
  }

  String _summary() {
    final leg = widget.leg;
    final departure = _formatMinutes(leg.schedule.departureMinutes);
    final arrival = _formatMinutes(leg.schedule.arrivalMinutes);
    final duration =
        leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
    final source = leg.usesEstimatedTravelTime ? '估計' : 'TDX';
    return '$departure 出發・$arrival 抵達・$source 約 $duration 分鐘';
  }

  Future<void> _openNavigation() async {
    setState(() => _isOpeningNavigation = true);
    try {
      final result = await _navigationService.openTravelLeg(widget.leg);
      if (!mounted) return;
      if (!result.launched) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('無法開啟 Google Maps')));
      } else if (!result.usedCurrentLocation) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('無法取得 GPS，已改用前一站作為起點')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('開啟導航失敗：$error')));
    } finally {
      if (mounted) setState(() => _isOpeningNavigation = false);
    }
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
      if (section.travelTime > 0) '約 ${(section.travelTime / 60).ceil()} 分鐘',
      if (section.stopCount > 0) '${section.stopCount} 站',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 15, child: Text('${index + 1}')),
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
