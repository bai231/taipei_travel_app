import '../models/trip.dart';
import '../models/place.dart';

import '../data/fake_trips.dart';

class TripService {
  List<Trip> getTrips() {
    return fakeTrips;
  }

  void addTrip(Trip trip) {
    fakeTrips.add(trip);
  }

  bool addPlaceToTrip({required Trip trip, required Place place}) {
    //避免重複加入

    bool alreadyExist = trip.places.any((item) => item.id == place.id);

    if (alreadyExist) {
      return false;
    }

    trip.places.add(place);

    updateTotalStayTime(trip);

    return true;
  }

  void updateTotalStayTime(Trip trip) {
    int total = 0;

    for (var place in trip.places) {
      total += place.stayTime;
    }

    trip.totalStayMinutes = total;
  }
}
