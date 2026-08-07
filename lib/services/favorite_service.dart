import '../models/place.dart';

class FavoriteService {
  // Singleton
  static final FavoriteService _instance = FavoriteService._internal();

  factory FavoriteService() {
    return _instance;
  }

  FavoriteService._internal();

  final List<Place> favorites = [];

  List<Place> getFavorites() {
    return favorites;
  }

  bool addFavorite(Place place) {
    bool exists = favorites.any((item) => item.id == place.id);

    if (exists) {
      return false;
    }

    favorites.add(place);

    return true;
  }

  bool removeFavorite(Place place) {
    favorites.removeWhere((item) => item.id == place.id);

    return true;
  }
}
