import 'package:flutter/material.dart';
import '../../services/language_service.dart';

class TripNameField extends StatelessWidget {
  final TextEditingController controller;

  const TripNameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: LanguageService.tr(context, 'trip_name'),
        hintText: LanguageService.tr(context, 'trip_name_example'),

        prefixIcon: const Icon(Icons.luggage),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
