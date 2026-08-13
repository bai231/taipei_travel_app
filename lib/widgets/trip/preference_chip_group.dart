import 'package:flutter/material.dart';

class PreferenceChipGroup extends StatelessWidget {
  final List<String> selectedPreferences;
  final ValueChanged<List<String>> onChanged;

  const PreferenceChipGroup({
    super.key,
    required this.selectedPreferences,
    required this.onChanged,
  });

  final List<String> preferences = const [
    "美食",
    "購物",
    "文化",
    "自然",
    "攝影",
    "夜景",
    "親子",
    "歷史",
    "藝術",
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          "旅遊偏好",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,

          children: preferences.map((preference) {
            final isSelected = selectedPreferences.contains(preference);

            return FilterChip(
              label: Text(preference),

              selected: isSelected,

              onSelected: (selected) {
                final newList = List<String>.from(selectedPreferences);

                if (selected) {
                  newList.add(preference);
                } else {
                  newList.remove(preference);
                }

                onChanged(newList);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
