import 'package:flutter/material.dart';

import '../models/generated_trip.dart';
import '../models/trip_item.dart';

class TripResultPage extends StatelessWidget {
  final GeneratedTrip trip;

  const TripResultPage({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    // 找出總共有幾天
    final days = trip.items.isEmpty
        ? 0
        : trip.items.map((item) => item.day).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text("你的行程")),

      body: trip.items.isEmpty
          ? const Center(
              child: Text("目前沒有可以安排的景點", style: TextStyle(fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: days,
              itemBuilder: (context, index) {
                final day = index + 1;

                final dayItems = trip.items
                    .where((item) => item.day == day)
                    .toList();

                return _buildDaySection(context, day, dayItems);
              },
            ),
    );
  }

  Widget _buildDaySection(BuildContext context, int day, List<TripItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        Text(
          "Day $day",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text("這一天目前沒有安排景點"),
          ),

        ...items.map((item) => _buildTripItem(context, item)),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTripItem(BuildContext context, TripItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // 左邊時間
            SizedBox(
              width: 75,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    _formatTime(item.startMinutes),

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _formatTime(item.endMinutes),

                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 中間分隔線
            Container(
              width: 3,
              height: 70,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(width: 12),

            // 景點
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    item.place.name,

                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    item.place.description,

                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(color: Colors.grey.shade700),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),

                      const SizedBox(width: 4),

                      Text(item.place.rating.toString()),
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

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    final hourString = hour.toString().padLeft(2, '0');

    final minuteString = minute.toString().padLeft(2, '0');

    return "$hourString:$minuteString";
  }
}
