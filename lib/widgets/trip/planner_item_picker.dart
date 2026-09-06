import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../services/place_service.dart';

class PlannerItemPicker extends StatefulWidget {
  final PlaceType type;
  final List<Place> places;
  final Set<String> selectedPlaceIds;
  final ValueChanged<List<Place>> onConfirmed;

  const PlannerItemPicker({
    super.key,
    required this.type,
    required this.places,
    required this.selectedPlaceIds,
    required this.onConfirmed,
  });

  @override
  State<PlannerItemPicker> createState() => _PlannerItemPickerState();
}

class _PlannerItemPickerState extends State<PlannerItemPicker> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _selectedPlaceIds;
  String? _selectedCounty;

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
    final typePlaces = widget.places
        .where((place) => place.type == widget.type)
        .toList();
    final counties = PlaceService.availableCounties(typePlaces);
    final filteredPlaces = PlaceService.filterCatalog(
      places: typePlaces,
      type: widget.type,
      county: _selectedCounty,
      keyword: _searchController.text,
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
                    '選擇${_typeName(widget.type)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '關閉',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋名稱、分類或地址',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除搜尋',
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
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCounty,
                    decoration: const InputDecoration(
                      labelText: '縣市',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部縣市'),
                      ),
                      ...counties.map(
                        (county) => DropdownMenuItem<String?>(
                          value: county,
                          child: Text(county),
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
                      '目前沒有符合條件的${_typeName(widget.type)}',
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
                            if (!isRoutable) '缺少座標，暫不可排入行程',
                            '⭐ ${place.rating}',
                            '停留 ${place.stayTime} 分鐘',
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
                    '已選 ${_selectedPlaceIds.length} 個${_typeName(widget.type)}',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(Icons.check),
                  label: const Text('套用選擇'),
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
      PlaceType.attraction => '景點',
      PlaceType.restaurant => '餐廳',
      PlaceType.accommodation => '住宿',
    };
  }

  IconData _typeIcon(PlaceType type) {
    return switch (type) {
      PlaceType.attraction => Icons.attractions,
      PlaceType.restaurant => Icons.restaurant,
      PlaceType.accommodation => Icons.hotel,
    };
  }
}
