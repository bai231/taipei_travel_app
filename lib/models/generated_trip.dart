import 'trip_item.dart';

class GeneratedTrip {
  final List<TripItem> items;

  GeneratedTrip({required this.items});

  List<TripItem> getItemsForDay(int day) {
    return items.where((item) => item.day == day).toList();
  }
}
