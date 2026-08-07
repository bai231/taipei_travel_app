import 'package:flutter/material.dart';

class BudgetField extends StatelessWidget {
  const BudgetField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,

      decoration: InputDecoration(
        labelText: "預算",

        hintText: "例如：8000 元",

        prefixIcon: const Icon(Icons.attach_money),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
