import 'package:flutter/material.dart';

class TripLocationField extends StatelessWidget {
  final String location;
  final ValueChanged<String?> onChanged;

  const TripLocationField({
    super.key,
    required this.location,
    required this.onChanged,
  });

  final List<String> locations = const [
    "台北市",
    "新北市",
    "桃園市",
    "台中市",
    "高雄市",
    "台南市",
    "花蓮縣",
    "宜蘭縣",
    "屏東縣",
    "南投縣",
    "嘉義縣",
    "嘉義市",
    "苗栗縣",
    "彰化縣",
    "台東縣",
    "雲林縣",
    "新竹市",
    "新竹縣",
    "基隆市",
    "澎湖縣",
    "金門縣",
    "連江縣",
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: location,

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
