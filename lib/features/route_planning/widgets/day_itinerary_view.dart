import 'package:flutter/material.dart';

import '../models/route_day.dart';
import '../models/route_visit.dart';
import 'travel_leg_card.dart';

class DayItineraryView extends StatelessWidget {
  final RouteDay day;

  const DayItineraryView({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    if (day.visits.isEmpty) {
      return const Center(child: Text('這一天尚未安排景點。'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (day.warnings.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '排程提醒',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...day.warnings.map((warning) => Text('• $warning')),
                ],
              ),
            ),
          ),
        for (var index = 0; index < day.visits.length; index++) ...[
          if (day.travelLegs.any(
            (leg) => leg.destination.id == day.visits[index].occurrenceId,
          ))
            TravelLegCard(
              leg: day.travelLegs.firstWhere(
                (leg) => leg.destination.id == day.visits[index].occurrenceId,
              ),
            ),
          _VisitCard(visit: day.visits[index]),
        ],
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  final RouteVisit visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text('${visit.sequence}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          visit.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (visit.locked)
                        const Icon(Icons.lock_outline, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatMinutes(visit.startMinutes)}–'
                    '${_formatMinutes(visit.endMinutes)}・'
                    '停留 ${visit.stayMinutes} 分鐘',
                  ),
                  if (visit.waitingMinutes > 0)
                    Text('提早抵達，等待 ${visit.waitingMinutes} 分鐘'),
                  const SizedBox(height: 4),
                  Text(
                    visit.place.address,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (visit.information.isNotEmpty)
                    ExpansionTile(
                      title: const Text('設定與資訊來源'),
                      children: [
                        for (final item in visit.information)
                          ListTile(title: Text(item)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
