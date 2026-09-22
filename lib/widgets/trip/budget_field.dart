import 'package:flutter/material.dart';

class BudgetField extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const BudgetField({super.key, required this.value, required this.onChanged});

  static const Map<int, String> _labels = {
    1: '節省',
    2: '平價',
    3: '適中',
    4: '高級',
    5: '奢華',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '預算等級',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 4),

        Text(
          '1 最省・5 最高',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _labels.entries.map((entry) {
            return ChoiceChip(
              label: Text('${entry.key} ${entry.value}'),
              selected: value == entry.key,
              showCheckmark: false,
              onSelected: (_) {
                onChanged(entry.key);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
