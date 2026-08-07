import 'package:flutter/material.dart';

class PeopleCounter extends StatefulWidget {
  const PeopleCounter({super.key});

  @override
  State<PeopleCounter> createState() => _PeopleCounterState();
}

class _PeopleCounterState extends State<PeopleCounter> {
  int people = 1;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "旅遊人數",

        prefixIcon: const Icon(Icons.people),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          IconButton(
            icon: const Icon(Icons.remove),

            onPressed: () {
              if (people > 1) {
                setState(() {
                  people--;
                });
              }
            },
          ),

          Text("$people 人", style: const TextStyle(fontSize: 18)),

          IconButton(
            icon: const Icon(Icons.add),

            onPressed: () {
              setState(() {
                people++;
              });
            },
          ),
        ],
      ),
    );
  }
}
