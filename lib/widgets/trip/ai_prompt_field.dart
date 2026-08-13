import 'package:flutter/material.dart';

class AIPromptField extends StatelessWidget {
  final TextEditingController controller;

  const AIPromptField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,

      maxLines: 4,

      decoration: InputDecoration(
        labelText: "其他需求",
        hintText: "例如：希望行程悠閒一點，不要安排太多景點",
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
