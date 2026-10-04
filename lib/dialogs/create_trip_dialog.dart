import 'package:flutter/material.dart';
import '../services/language_service.dart';

Future<String?> showCreateTripDialog({required BuildContext context}) async {
  final TextEditingController controller = TextEditingController();

  return await showDialog<String>(
    context: context,

    builder: (context) {
      return AlertDialog(
        title: Text(LanguageService.tr(context, 'create_trip')),

        content: TextField(
          controller: controller,

          decoration: InputDecoration(
            hintText: LanguageService.tr(context, 'create_trip_example'),

            border: OutlineInputBorder(),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },

            child: Text(LanguageService.tr(context, 'dialog_cancel')),
          ),

          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                return;
              }

              Navigator.pop(context, controller.text.trim());
            },

            child: Text(LanguageService.tr(context, 'dialog_create')),
          ),
        ],
      );
    },
  );
}
