import 'package:flutter/material.dart';

class TripDateField extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  final VoidCallback onSelectDate;

  const TripDateField({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSelectDate,
  });

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '尚未選擇';
    }

    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelectDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '旅遊日期',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                startDate == null || endDate == null
                    ? '請選擇旅遊日期'
                    : '${_formatDate(startDate)} ～ '
                          '${_formatDate(endDate)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
