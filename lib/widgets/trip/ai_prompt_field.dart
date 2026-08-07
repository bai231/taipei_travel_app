import 'package:flutter/material.dart';

class AIPromptField extends StatelessWidget {
  const AIPromptField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 5,

      decoration: InputDecoration(
        labelText: "其他需求",

        hintText:
            "例如：\n"
            "想拍很多夜景\n"
            "不要安排太趕的行程",

        alignLabelWithHint: true,

        prefixIcon: const Icon(Icons.auto_awesome),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
