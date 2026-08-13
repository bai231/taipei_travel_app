import 'package:flutter/material.dart';

class BudgetField extends StatelessWidget {
  final TextEditingController controller;

  const BudgetField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,

      decoration: InputDecoration(
        labelText: "預算",
        hintText: "例如：5000",
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: "元",

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
