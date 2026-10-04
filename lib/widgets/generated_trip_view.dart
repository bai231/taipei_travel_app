import 'package:flutter/material.dart';

import '../models/generated_trip.dart';
import '../services/language_service.dart';
import '../theme/app_typography.dart';
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

        Text(
          LanguageService.tr(context, 'recommended_itinerary'),
          style: AppTypography.headline(),
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
          style: AppTypography.sectionTitle(),
        ),

        const Divider(),

        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(LanguageService.tr(context, 'trip_day_no_spots'), style: const TextStyle(color: Colors.grey)),
          ),

        ...items.map((item) => TripItemCard(item: item)),
      ],
    );
  }
}
