import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';
import 'create_trip_dialog.dart';
import '../models/place.dart';

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
        title: const Text("加入行程"),

        content: SizedBox(
          width: double.maxFinite,

          child: trips.isEmpty
              ? const Text("目前沒有任何行程")
              : ListView.builder(
                  shrinkWrap: true,

                  itemCount: trips.length,

                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(trips[index].name),

                      subtitle: Text("${trips[index].places.length} 個景點"),

                      onTap: () {
                        final success = tripService.addPlaceToTrip(
                          trip: trips[index],

                          place: place,
                        );

                        Navigator.pop(context);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${place.name} 已加入 ${trips[index].name}",
                              ),
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

            label: const Text("建立新行程"),
          ),
        ],
      );
    },
  );
}
