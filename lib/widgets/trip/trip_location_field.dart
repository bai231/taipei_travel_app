import 'package:flutter/material.dart';

class TripLocationField extends StatelessWidget {
  final String location;
  final ValueChanged<String?> onChanged;

  const TripLocationField({
    super.key,
    required this.location,
    required this.onChanged,
  });

  final List<String> locations = const ["台北市", "新北市", "桃園市", "台中市", "高雄市"];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: location,

      decoration: InputDecoration(
        labelText: "旅遊地點",
        prefixIcon: const Icon(Icons.location_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),

      items: locations.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),

      onChanged: onChanged,
    );
  }
}
