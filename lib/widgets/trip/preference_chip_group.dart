import 'package:flutter/material.dart';

class PreferenceChipGroup extends StatefulWidget {
  const PreferenceChipGroup({super.key});

  @override
  State<PreferenceChipGroup> createState() => _PreferenceChipGroupState();
}

class _PreferenceChipGroupState extends State<PreferenceChipGroup> {
  final List<String> preferences = [
    "美食",
    "攝影",
    "夜景",
    "自然",
    "購物",
    "咖啡廳",
    "博物館",
    "文創",
    "親子",
  ];

  final List<String> selected = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          "旅遊偏好",

          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 8,

          runSpacing: 8,

          children: preferences.map((item) {
            bool isSelected = selected.contains(item);

            return FilterChip(
              label: Text(item),

              selected: isSelected,

              onSelected: (value) {
                setState(() {
                  if (value) {
                    selected.add(item);
                  } else {
                    selected.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
