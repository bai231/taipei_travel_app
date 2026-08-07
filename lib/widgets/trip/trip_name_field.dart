import 'package:flutter/material.dart';

class TripNameField extends StatelessWidget {
  const TripNameField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: "行程名稱",
        hintText: "例如：台北兩天一夜",

        prefixIcon: const Icon(Icons.luggage),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
