import 'package:flutter/material.dart';

class PeopleCounter extends StatelessWidget {
  final int people;
  final ValueChanged<int> onChanged;

  const PeopleCounter({
    super.key,
    required this.people,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.people),

          const SizedBox(width: 12),

          const Expanded(child: Text("旅遊人數", style: TextStyle(fontSize: 16))),

          IconButton(
            onPressed: people > 1
                ? () {
                    onChanged(people - 1);
                  }
                : null,
            icon: const Icon(Icons.remove),
          ),

          Text(
            "$people 人",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          IconButton(
            onPressed: people < 20
                ? () {
                    onChanged(people + 1);
                  }
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
