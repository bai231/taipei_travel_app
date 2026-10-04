import 'package:flutter/material.dart';
import '../../services/language_service.dart';

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

  String _preferenceKey(String preference) => switch (preference) {
    '美食' => 'pref_food',
    '購物' => 'pref_shopping',
    '文化' => 'pref_culture',
    '自然' => 'pref_nature',
    '攝影' => 'pref_photography',
    '夜景' => 'pref_night_view',
    '親子' => 'pref_family',
    '歷史' => 'pref_history',
    '藝術' => 'pref_art',
    _ => preference,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          LanguageService.tr(context, 'travel_pref_trip'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,

          children: preferences.map((preference) {
            final isSelected = selectedPreferences.contains(preference);

            return FilterChip(
              label: Text(LanguageService.tr(context, _preferenceKey(preference))),

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
