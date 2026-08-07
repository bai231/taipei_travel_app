import 'package:flutter/material.dart';

class TripLocationField extends StatefulWidget {
  const TripLocationField({super.key});

  @override
  State<TripLocationField> createState() => _TripLocationFieldState();
}

class _TripLocationFieldState extends State<TripLocationField> {
  String location = "台北市";

  final locations = ["台北市", "新北市", "桃園市", "台中市", "高雄市"];

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
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),

      onChanged: (value) {
        setState(() {
          location = value!;
        });
      },
    );
  }
}
