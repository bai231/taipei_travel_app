import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final ValueChanged<String>? onChanged;

  const SearchBarWidget({
    super.key,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,

      decoration: InputDecoration(
        hintText: '搜尋景點、美食、地點...',

        prefixIcon: const Icon(
          Icons.search,
        ),

        filled: true,

        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}