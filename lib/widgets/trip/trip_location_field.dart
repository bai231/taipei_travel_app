import 'package:flutter/material.dart';
import '../../services/language_service.dart';

class TripLocationField extends StatelessWidget {
  final List<String> selectedLocations;
  final ValueChanged<List<String>> onChanged;

  const TripLocationField({
    super.key,
    required this.selectedLocations,
    required this.onChanged,
  });

  static const List<String> locations = [
    "台北市",
    "新北市",
    "桃園市",
    "台中市",
    "高雄市",
    "台南市",
    "花蓮縣",
    "宜蘭縣",
    "屏東縣",
    "南投縣",
    "嘉義縣",
    "嘉義市",
    "苗栗縣",
    "彰化縣",
    "台東縣",
    "雲林縣",
    "新竹市",
    "新竹縣",
    "基隆市",
    "澎湖縣",
    "金門縣",
    "連江縣",
  ];

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
<<<<<<< HEAD
        labelText: LanguageService.tr(context, 'trip_location'),
=======
        labelText: '旅遊地點（可複選）',
>>>>>>> 457d2717a0522e7adb97a540f701041dee54757e
        prefixIcon: const Icon(Icons.location_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: locations.map((location) {
          final isSelected = selectedLocations.contains(location);

          return FilterChip(
            label: Text(location),
            selected: isSelected,
            onSelected: (selected) {
              final updatedLocations = List<String>.from(selectedLocations);

              if (selected) {
                if (!updatedLocations.contains(location)) {
                  updatedLocations.add(location);
                }
              } else {
                updatedLocations.remove(location);
              }

              onChanged(updatedLocations);
            },
          );
        }).toList(),
      ),
    );
  }
}
