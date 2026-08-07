import 'package:flutter/material.dart';

class TripDateField extends StatefulWidget {
  const TripDateField({super.key});

  @override
  State<TripDateField> createState() => _TripDateFieldState();
}

class _TripDateFieldState extends State<TripDateField> {
  DateTime? startDate;
  DateTime? endDate;

  Future<void> selectDate() async {
    DateTimeRange? range = await showDateRangePicker(
      context: context,

      firstDate: DateTime.now(),

      lastDate: DateTime(2030),
    );

    if (range != null) {
      setState(() {
        startDate = range.start;

        endDate = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selectDate,

      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "旅遊日期",

          prefixIcon: const Icon(Icons.calendar_month),

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),

        child: Text(
          startDate == null
              ? "請選擇日期"
              : "${startDate!.year}/"
                    "${startDate!.month}/"
                    "${startDate!.day}"
                    " ~ "
                    "${endDate!.year}/"
                    "${endDate!.month}/"
                    "${endDate!.day}",
        ),
      ),
    );
  }
}
