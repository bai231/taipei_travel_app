import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BudgetField extends StatelessWidget {
  final TextEditingController controller;

  const BudgetField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: "行程總預算",
        hintText: "例如：10000",
        helperText: "所有旅客整趟行程可使用的總預算",
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: "元",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
