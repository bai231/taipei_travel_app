import 'package:flutter/material.dart';

Future<String?> showCreateTripDialog({required BuildContext context}) async {
  final TextEditingController controller = TextEditingController();

  return await showDialog<String>(
    context: context,

    builder: (context) {
      return AlertDialog(
        title: const Text("建立新行程"),

        content: TextField(
          controller: controller,

          decoration: const InputDecoration(
            hintText: "例如：台北一日遊",

            border: OutlineInputBorder(),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },

            child: const Text("取消"),
          ),

          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                return;
              }

              Navigator.pop(context, controller.text.trim());
            },

            child: const Text("建立"),
          ),
        ],
      );
    },
  );
}
