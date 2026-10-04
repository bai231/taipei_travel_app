import 'package:flutter/material.dart';
import '../../services/language_service.dart';

class BudgetField extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const BudgetField({super.key, required this.value, required this.onChanged});

  static const Map<int, String> _labelKeys = {
    1: 'budget_save',
    2: 'budget_affordable',
    3: 'budget_moderate',
    4: 'budget_upscale',
    5: 'budget_luxury',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LanguageService.tr(context, 'budget_level'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 4),

        Text(
          LanguageService.tr(context, 'budget_scale_hint'),
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _labelKeys.entries.map((entry) {
            return ChoiceChip(
              label: Text(
                '${entry.key} ${LanguageService.tr(context, entry.value)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
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
