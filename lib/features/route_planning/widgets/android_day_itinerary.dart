import 'package:flutter/material.dart';
import '../models/route_day.dart';
import '../models/route_visit.dart';

class AndroidDayItinerary extends StatelessWidget {
  final List<RouteDay> days;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<RouteVisit>? onEdit;
  final ValueChanged<RouteVisit>? onDelete;
  final ValueChanged<RouteVisit> onTravel;
  final Widget? timetable;
  const AndroidDayItinerary({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onDayChanged,
    this.onEdit,
    this.onDelete,
    required this.onTravel,
    this.timetable,
  });

  String time(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Text(
                    'Day ${days[i].day} · ${days[i].date.month}/${days[i].date.day}',
                  ),
                  selected: selectedDay == i,
                  onSelected: (_) => onDayChanged(i),
                ),
              ),
          ],
        ),
      ),
      if (timetable != null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('長按景點可拖到新的時間', style: TextStyle(fontSize: 12)),
        ),
      Expanded(
        child:
            timetable ??
            ListView(
              key: ValueKey('android-day-$selectedDay'),
              padding: const EdgeInsets.all(12),
              children: [
                if (days[selectedDay].visits.isEmpty) const Text('這天尚無行程'),
                for (final visit in days[selectedDay].visits)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${time(visit.startMinutes)}–${time(visit.endMinutes)}',
                          ),
                          Text(
                            visit.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: onEdit == null
                                    ? null
                                    : () => onEdit!(visit),
                                child: const Text('設定／資訊'),
                              ),
                              if (days[selectedDay].travelLegs.any(
                                (leg) =>
                                    leg.destination.id == visit.occurrenceId,
                              ))
                                TextButton(
                                  onPressed: () => onTravel(visit),
                                  child: const Text('交通方式'),
                                ),
                              TextButton(
                                onPressed: onDelete == null
                                    ? null
                                    : () => onDelete!(visit),
                                child: const Text('移除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      ),
    ],
  );
}
