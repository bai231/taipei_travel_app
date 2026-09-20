import 'package:flutter/material.dart';
import '../../../widgets/trip/android_layout.dart';

import '../../../models/tdx_route.dart';
import '../../../services/google_maps_navigation_service.dart';
import '../models/route_travel_mode.dart';
import '../models/travel_leg.dart';

class TravelLegCard extends StatefulWidget {
  final TravelLeg leg;
  final ValueChanged<RouteTravelMode>? onTravelModeChanged;

  const TravelLegCard({super.key, required this.leg, this.onTravelModeChanged});

  @override
  State<TravelLegCard> createState() => _TravelLegCardState();
}

class _TravelLegCardState extends State<TravelLegCard> {
  final GoogleMapsNavigationService _navigationService =
      GoogleMapsNavigationService();
  bool _isOpeningNavigation = false;
  bool _showDetails = false;

  @override
  void didUpdateWidget(covariant TravelLegCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.leg, widget.leg)) _showDetails = false;
  }

  @override
  Widget build(BuildContext context) {
    final leg = widget.leg;
    final route = leg.route;
    final colorScheme = Theme.of(context).colorScheme;
    final usesEstimate = route == null;
    if (usesAndroidTripLayout) return _buildAndroidCard(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: usesEstimate
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        initiallyExpanded: widget.onTravelModeChanged != null,
        leading: Icon(
          usesEstimate ? Icons.info_outline : Icons.directions,
          color: usesEstimate ? colorScheme.onSecondaryContainer : null,
        ),
        title: Text('${leg.origin.name} → ${leg.destination.name}'),
        subtitle: Text(_summary()),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (widget.onTravelModeChanged != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<RouteTravelMode>(
                segments: [
                  for (final mode in RouteTravelMode.values)
                    ButtonSegment(value: mode, label: Text(mode.label)),
                ],
                selected: {leg.travelMode},
                onSelectionChanged: (selection) {
                  final mode = selection.single;
                  if (mode != leg.travelMode) {
                    widget.onTravelModeChanged!(mode);
                  }
                },
              ),
            ),
          if (widget.onTravelModeChanged != null) const SizedBox(height: 8),
          if (leg.errorMessage != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                leg.errorMessage!,
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
          if (route != null && route.sections.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${leg.travelMode.sourceLabel} 沒有提供更細的路段資訊。'),
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

  Widget _buildAndroidCard(BuildContext context) {
    final leg = widget.leg;
    final route = leg.route;
    final duration =
        leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${leg.origin.name} → ${leg.destination.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${leg.travelMode.label} · 約 $duration 分鐘${route == null ? '（估計）' : ''}',
            ),
            Text(
              '${_formatMinutes(leg.schedule.departureMinutes)} 出發 → ${_formatMinutes(leg.schedule.arrivalMinutes)} 抵達',
            ),
            if (route != null && route.transfers > 0)
              Text('轉乘 ${route.transfers} 次'),
            if (route == null) const Text('尚未取得實際路線，時間僅供參考。'),
            if (leg.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(leg.errorMessage!),
              ),
            if (widget.onTravelModeChanged != null)
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in RouteTravelMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: mode == leg.travelMode,
                      onSelected: (_) {
                        if (mode != leg.travelMode) {
                          widget.onTravelModeChanged!(mode);
                        }
                      },
                    ),
                ],
              ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  icon: Icon(
                    _showDetails ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(_showDetails ? '收合細項' : '展開細項'),
                ),
                OutlinedButton.icon(
                  onPressed: _isOpeningNavigation ? null : _openNavigation,
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Google Maps 導航'),
                ),
              ],
            ),
            if (route != null)
              for (final entry in route.sections.asMap().entries)
                _RouteSectionTile(
                  key: ObjectKey(entry.value),
                  index: entry.key,
                  section: entry.value,
                  collapsible: true,
                ),
            if (_showDetails) ...[
              const Divider(),
              Text('資料來源：${leg.routeSourceLabel}'),
              if (route?.distanceMeters != null)
                Text('距離：${route!.distanceMeters} 公尺'),
              if (route == null || route.sections.isEmpty)
                const Text('目前沒有更細的路段資訊。'),
            ],
          ],
        ),
      ),
    );
  }

  String _summary() {
    final leg = widget.leg;
    final departure = _formatMinutes(leg.schedule.departureMinutes);
    final arrival = _formatMinutes(leg.schedule.arrivalMinutes);
    final duration =
        leg.schedule.arrivalMinutes - leg.schedule.departureMinutes;
    final distance = leg.route?.distanceMeters;
    final distanceLabel = distance == null
        ? ''
        : distance < 1000
        ? '・$distance 公尺'
        : '・${(distance / 1000).toStringAsFixed(1)} 公里';
    return '$departure 出發・$arrival 抵達・'
        '${leg.routeSourceLabel} 約 $duration 分鐘$distanceLabel';
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
  final bool collapsible;

  const _RouteSectionTile({
    super.key,
    required this.index,
    required this.section,
    this.collapsible = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (section.departureTime != null) '${section.departureTime} 出發',
      if (section.arrivalTime != null) '${section.arrivalTime} 抵達',
      if (section.travelTime > 0) '約 ${(section.travelTime / 60).ceil()} 分鐘',
      if (section.stopCount > 0) '${section.stopCount} 站',
    ];
    if (collapsible) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(radius: 15, child: Text('${index + 1}')),
        title: Text(
          [
            _modeLabel(section.mode),
            if (section.lineName?.isNotEmpty ?? false) section.lineName!,
          ].join('・'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${section.travelTime > 0 ? '約 ${(section.travelTime / 60).ceil()} 分鐘 · ' : ''}展開站名細項',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          DefaultTextStyle(
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(fontSize: 13),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details.isNotEmpty) Text(details.join('・')),
                  if (section.destination?.isNotEmpty ?? false)
                    Text('方向：${section.destination}'),
                  if (section.departureTitle != null ||
                      section.arrivalTitle != null)
                    Text(
                      '${section.departureTitle ?? '起點'} → ${section.arrivalTitle ?? '終點'}',
                    ),
                  if (section.intermediateStops.isNotEmpty)
                    Text('途經：${section.intermediateStops.join('、')}'),
                ],
              ),
            ),
          ),
        ],
      );
    }
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
        return '台鐵／火車';
      case 'high_speed_rail':
      case 'high_speed_train':
      case 'thsr':
        return '高鐵';
      case 'ferry':
      case 'ship':
        return '渡輪';
      case 'cable_car':
      case 'gondola':
        return '纜車';
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
