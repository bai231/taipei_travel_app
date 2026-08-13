import 'package:flutter/material.dart';

import '../models/generated_trip.dart';
import 'trip_item_card.dart';

class GeneratedTripView extends StatelessWidget {
  final GeneratedTrip trip;
  final int days;

  const GeneratedTripView({super.key, required this.trip, required this.days});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        const Text(
          '推薦行程',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        for (int day = 1; day <= days; day++) _buildDay(context, day),
      ],
    );
  }

  Widget _buildDay(BuildContext context, int day) {
    final items = trip.getItemsForDay(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Text(
          'Day $day',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const Divider(),

        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('這一天目前沒有安排景點', style: TextStyle(color: Colors.grey)),
          ),

        ...items.map((item) => TripItemCard(item: item)),
      ],
    );
  }
}
