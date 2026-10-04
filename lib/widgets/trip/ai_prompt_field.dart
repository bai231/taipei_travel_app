import 'package:flutter/material.dart';
import '../../services/language_service.dart';

class AIPromptField extends StatelessWidget {
  final TextEditingController controller;

  const AIPromptField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,

      maxLines: 4,

      decoration: InputDecoration(
        labelText: LanguageService.tr(context, 'other_requirements'),
        hintText: LanguageService.tr(context, 'trip_other_requirements_hint'),
        alignLabelWithHint: true,

        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.auto_awesome),
        ),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
