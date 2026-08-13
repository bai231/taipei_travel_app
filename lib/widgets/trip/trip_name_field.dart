import 'package:flutter/material.dart';

class TripNameField extends StatelessWidget {
  final TextEditingController controller;

  const TripNameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: "行程名稱",
        hintText: "例如：台北兩天一夜",

        prefixIcon: const Icon(Icons.luggage),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
