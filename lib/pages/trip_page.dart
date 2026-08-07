import 'package:flutter/material.dart';
import '../widgets/trip/trip_date_field.dart';
import '../widgets/trip/trip_location_field.dart';
import '../widgets/trip/people_counter.dart';
import '../widgets/trip/trip_name_field.dart';
import '../widgets/trip/budget_field.dart';
import '../widgets/trip/preference_chip_group.dart';
import '../widgets/trip/ai_prompt_field.dart';
import '../widgets/trip/next_step_button.dart';

class TripPage extends StatelessWidget {
  const TripPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("建立新行程")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "旅遊基本資訊",

              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),
            const TripNameField(),

            const SizedBox(height: 16),
            const TripDateField(),

            const SizedBox(height: 16),
            const TripLocationField(),

            const SizedBox(height: 16),
            const PeopleCounter(),

            const SizedBox(height: 16),
            const BudgetField(),

            const SizedBox(height: 24),
            const PreferenceChipGroup(),

            const SizedBox(height: 24),
            const AIPromptField(),

            const SizedBox(height: 30),
            NextStepButton(
              onPressed: () {
                print("開始AI規劃");
              },
            ),
          ],
        ),
      ),
    );
  }
}
