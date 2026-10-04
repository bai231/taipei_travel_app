import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';
import 'create_trip_dialog.dart';
import '../models/place.dart';
import '../services/language_service.dart';

Future<void> showAddToTripDialog({
  required BuildContext context,
  required Place place,
}) async {
  final TripService tripService = TripService();

  await showDialog(
    context: context,

    builder: (context) {
      final trips = tripService.getTrips();

      return AlertDialog(
        title: Text(LanguageService.tr(context, 'add_to_trip_dialog_title')),

        content: SizedBox(
          width: double.maxFinite,

          child: trips.isEmpty
              ? Text(LanguageService.tr(context, 'add_to_trip_empty'))
              : ListView.builder(
                  shrinkWrap: true,

                  itemCount: trips.length,

                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(trips[index].name),

                      subtitle: Text(LanguageService.tr(context, 'add_to_trip_spot_count').replaceAll('{count}', '${trips[index].places.length}')),

                      onTap: () {
                        final success = tripService.addPlaceToTrip(
                          trip: trips[index],

                          place: place,
                        );

                        Navigator.pop(context);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LanguageService.tr(context, 'add_to_trip_success').replaceAll('{place}', place.name).replaceAll('{trip}', trips[index].name)),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),

        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              final name = await showCreateTripDialog(context: context);

              if (name != null) {
                final newTrip = Trip(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),

                  name: name,

                  places: [],

                  note: "",

                  coverImage: "",

                  createdTime: DateTime.now(),

                  totalStayMinutes: 0,
                );

                tripService.addTrip(newTrip);
                tripService.addPlaceToTrip(trip: newTrip, place: place);
              }
            },

            icon: const Icon(Icons.add),

            label: Text(LanguageService.tr(context, 'create_trip')),
          ),
        ],
      );
    },
  );
}
