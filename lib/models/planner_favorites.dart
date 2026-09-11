class PlannerFavoriteFolder {
  final String id;
  final String title;
  final Set<String> placeIds;

  PlannerFavoriteFolder({
    required this.id,
    required this.title,
    required Set<String> placeIds,
  }) : placeIds = Set.unmodifiable(placeIds);
}

class PlannerFavorites {
  final Set<String> placeIds;
  final List<PlannerFavoriteFolder> folders;

  PlannerFavorites({required Set<String> placeIds, required this.folders})
    : placeIds = Set.unmodifiable(placeIds);
}
