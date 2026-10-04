import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../models/planner_favorites.dart';
import '../../services/place_service.dart';
import '../../services/planner_candidate_ranking.dart';
import '../../services/language_service.dart';

class PlannerItemPicker extends StatefulWidget {
  final PlaceType type;
  final List<Place> places;

  /// Optional teammate-defined scores; affects display order only.
  final Map<String, num> candidateScoresByPlaceId;
  final Set<String> selectedPlaceIds;
  final ValueChanged<List<Place>> onConfirmed;
  final Set<String>? favoritePlaceIds;
  final List<PlannerFavoriteFolder> favoriteFolders;
  final String favoritesUnavailableMessage;

  const PlannerItemPicker({
    super.key,
    required this.type,
    required this.places,
    this.candidateScoresByPlaceId = const {},
    required this.selectedPlaceIds,
    required this.onConfirmed,
    this.favoritePlaceIds,
    this.favoriteFolders = const [],
    this.favoritesUnavailableMessage = '收藏功能準備中，請先使用全部清單',
  });

  @override
  State<PlannerItemPicker> createState() => _PlannerItemPickerState();
}

class _PlannerItemPickerState extends State<PlannerItemPicker> {
  static const _uncategorizedFolderId = '__uncategorized__';
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _selectedPlaceIds;
  String? _selectedCounty;
  String? _selectedFolderId;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedPlaceIds = widget.places
        .where(
          (place) =>
              place.type == widget.type &&
              PlaceService.hasUsableCoordinates(place) &&
              widget.selectedPlaceIds.contains(place.id),
        )
        .map((place) => place.id)
        .toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesMode = widget.type == PlaceType.attraction && _favoritesOnly;
    final folderId =
        _selectedFolderId == _uncategorizedFolderId ||
            widget.favoriteFolders.any((f) => f.id == _selectedFolderId)
        ? _selectedFolderId
        : null;
    final folder = folderId == null || folderId == _uncategorizedFolderId
        ? null
        : widget.favoriteFolders.firstWhere((f) => f.id == folderId);
    final categorizedPlaceIds = widget.favoriteFolders
        .expand((folder) => folder.placeIds)
        .toSet();
    final typePlaces = widget.places
        .where((place) => place.type == widget.type)
        .toList();
    final counties = PlaceService.availableCounties(typePlaces);
    final matchingPlaces = PlaceService.filterCatalog(
      places: favoritesMode
          ? typePlaces.where(
              (place) =>
                  (widget.favoritePlaceIds?.contains(place.id) ?? false) &&
                  (folderId == _uncategorizedFolderId
                      ? !categorizedPlaceIds.contains(place.id)
                      : folder == null || folder.placeIds.contains(place.id)),
            )
          : typePlaces,
      type: widget.type,
      county: favoritesMode ? null : _selectedCounty,
      keyword: _searchController.text,
    );
    final filteredPlaces = rankPlannerCandidates(
      matchingPlaces,
      scoresByPlaceId: widget.candidateScoresByPlaceId,
    );

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(_typeIcon(widget.type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LanguageService.tr(context, 'picker_choose_type')
                        .replaceAll('{type}', _typeName(widget.type)),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: LanguageService.tr(context, 'picker_close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (widget.type == PlaceType.attraction)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(LanguageService.tr(context, 'picker_all')),
                    selected: !_favoritesOnly,
                    onSelected: (_) => setState(() => _favoritesOnly = false),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.favorite_border, size: 18),
                    label: Text(LanguageService.tr(context, 'picker_favorites')),
                    selected: _favoritesOnly,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _favoritesOnly = true),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Flex(
              mainAxisSize: MainAxisSize.min,
              direction:
                  MediaQuery.sizeOf(context).width < 600 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20
                  ? Axis.vertical
                  : Axis.horizontal,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: LanguageService.tr(context, 'picker_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: LanguageService.tr(context, 'picker_clear_search'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12, height: 12),
                Flexible(
                  fit: FlexFit.loose,
                  child: favoritesMode
                      ? DropdownButtonFormField<String?>(
                          key: ValueKey('folders:$folderId'),
                          initialValue: folderId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: LanguageService.tr(context, 'picker_folders'),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(LanguageService.tr(context, 'picker_all_favorites')
                                  .replaceAll('{count}', '$_favoriteCount')),
                            ),
                            DropdownMenuItem<String?>(
                              value: _uncategorizedFolderId,
                              child: Text(LanguageService.tr(context, 'picker_uncategorized')
                                  .replaceAll('{count}', '${_uncategorizedCount(categorizedPlaceIds)}')),
                            ),
                            ...widget.favoriteFolders.map(
                              (folder) => DropdownMenuItem<String?>(
                                value: folder.id,
                                child: Text(
                                  folder.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: widget.favoritePlaceIds == null
                              ? null
                              : (value) =>
                                    setState(() => _selectedFolderId = value),
                        )
                      : DropdownButtonFormField<String?>(
                          key: const ValueKey('counties'),
                          initialValue: _selectedCounty,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: LanguageService.tr(context, 'picker_counties'),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(LanguageService.tr(context, 'picker_all_counties')),
                            ),
                            ...counties.map(
                              (county) => DropdownMenuItem<String?>(
                                value: county,
                                child: Text(
                                  county,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCounty = value);
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: filteredPlaces.isEmpty
                ? Center(
                    child: Text(
                      favoritesMode && widget.favoritePlaceIds == null
                          ? widget.favoritesUnavailableMessage
                          : favoritesMode
                          ? LanguageService.tr(context, 'picker_no_favorites')
                              .replaceAll('{type}', _typeName(widget.type))
                          : LanguageService.tr(context, 'picker_no_places')
                              .replaceAll('{type}', _typeName(widget.type)),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredPlaces.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = filteredPlaces[index];
                      final alreadyAdded = _selectedPlaceIds.contains(place.id);
                      final county = PlaceService.countyFor(place);
                      final isRoutable = PlaceService.hasUsableCoordinates(
                        place,
                      );

                      return CheckboxListTile(
                        value: alreadyAdded,
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: CircleAvatar(
                          child: Icon(_typeIcon(place.type)),
                        ),
                        title: Text(place.name),
                        subtitle: Text(
                          [
                            if (county.isNotEmpty) county,
                            if (place.category.isNotEmpty) place.category,
                            if (!isRoutable) LanguageService.tr(context, 'picker_no_coordinates'),
                            '⭐ ${place.rating}',
                            LanguageService.tr(context, 'picker_stay')
                                .replaceAll('{minutes}', '${place.stayTime}'),
                          ].join('・'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: isRoutable
                            ? (_) => _togglePlace(place)
                            : null,
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    LanguageService.tr(context, 'picker_selected')
                        .replaceAll('{count}', '${_selectedPlaceIds.length}')
                        .replaceAll('{type}', _typeName(widget.type)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(Icons.check),
                  label: Text(LanguageService.tr(context, 'picker_apply')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlace(Place place) {
    setState(() {
      if (!_selectedPlaceIds.remove(place.id)) {
        _selectedPlaceIds.add(place.id);
      }
    });
  }

  void _confirmSelection() {
    widget.onConfirmed(
      widget.places
          .where(
            (place) =>
                place.type == widget.type &&
                _selectedPlaceIds.contains(place.id),
          )
          .toList(),
    );
    Navigator.pop(context);
  }

  String _typeName(PlaceType type) {
    return switch (type) {
      PlaceType.attraction => LanguageService.trCurrent('place_category_attraction'),
      PlaceType.restaurant => LanguageService.trCurrent('place_category_restaurant'),
      PlaceType.accommodation => LanguageService.trCurrent('place_category_accommodation'),
    };
  }

  int get _favoriteCount => widget.places
      .where((place) =>
          place.type == widget.type &&
          (widget.favoritePlaceIds?.contains(place.id) ?? false))
      .length;

  int _uncategorizedCount(Set<String> categorizedPlaceIds) => widget.places
      .where((place) =>
          place.type == widget.type &&
          (widget.favoritePlaceIds?.contains(place.id) ?? false) &&
          !categorizedPlaceIds.contains(place.id))
      .length;

  IconData _typeIcon(PlaceType type) {
    return switch (type) {
      PlaceType.attraction => Icons.attractions,
      PlaceType.restaurant => Icons.restaurant,
      PlaceType.accommodation => Icons.hotel,
    };
  }
}
