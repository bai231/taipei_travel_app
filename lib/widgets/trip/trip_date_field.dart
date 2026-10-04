import 'package:flutter/material.dart';
import '../../services/language_service.dart';

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

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) {
      return LanguageService.tr(context, 'trip_date_not_selected');
    }

    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelectDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: LanguageService.tr(context, 'trip_date'),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                startDate == null || endDate == null
                    ? LanguageService.tr(context, 'trip_date_select_prompt')
                    : '${_formatDate(context, startDate)} ～ '
                          '${_formatDate(context, endDate)}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
