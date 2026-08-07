import '../models/place.dart';
import '../data/fake_places.dart';

class PlaceService {
  List<Place> getPlaces() {
    return fakePlaces;
  }
}
