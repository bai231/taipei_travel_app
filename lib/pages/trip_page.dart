import 'package:flutter/material.dart';
import '../widgets/trip/trip_date_field.dart';
import '../widgets/trip/trip_location_field.dart';
import '../widgets/trip/people_counter.dart';
import '../widgets/trip/trip_name_field.dart';
import '../widgets/trip/budget_field.dart';
import '../widgets/trip/preference_chip_group.dart';
import '../widgets/trip/ai_prompt_field.dart';
import '../widgets/trip/next_step_button.dart';
import '../models/trip_request.dart';
import '../services/recommandation_service.dart';
import '../services/trip_generator_service.dart';
import '../services/place_service.dart';
import '../pages/trip_result_page.dart';
import '../models/trip_place_constraint.dart';
import 'trip_planner_page.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  final RecommendService _recommendService = RecommendService();
  final TripGeneratorService _tripGeneratorService = TripGeneratorService();
  final PlaceService _placeService = PlaceService();

  final TextEditingController _tripNameController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  String _location = "台北市";

  int _people = 1;

  final TextEditingController _budgetController = TextEditingController();

  List<String> _preferences = [];

  final TextEditingController _aiPromptController = TextEditingController();

  Future<void> _selectDateRange() async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _startDate = result.start;
      _endDate = result.end;
    });
  }

  void _generateTrip() {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先選擇旅遊日期")));

      return;
    }

    if (_budgetController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請輸入預算")));

      return;
    }

    final request = TripRequest(
      title: _tripNameController.text,
      startDate: _startDate!,
      endDate: _endDate!,
      location: _location,
      people: _people,
      budget: double.parse(_budgetController.text),
      preferences: _preferences,
      aiPrompt: _aiPromptController.text,
    );

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (context) => TripPlannerPage(
          request: request,

          // 目前先把所有景點傳進去
          places: _placeService.getPlaces(),
        ),
      ),
    );
  }

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
            TripNameField(controller: _tripNameController),

            const SizedBox(height: 16),
            TripDateField(
              startDate: _startDate,
              endDate: _endDate,
              onSelectDate: _selectDateRange,
            ),

            const SizedBox(height: 16),
            TripLocationField(
              location: _location,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _location = value;
                });
              },
            ),

            const SizedBox(height: 16),
            PeopleCounter(
              people: _people,
              onChanged: (value) {
                setState(() {
                  _people = value;
                });
              },
            ),

            const SizedBox(height: 16),
            BudgetField(controller: _budgetController),

            const SizedBox(height: 24),
            PreferenceChipGroup(
              selectedPreferences: _preferences,
              onChanged: (value) {
                setState(() {
                  _preferences = value;
                });
              },
            ),

            const SizedBox(height: 24),
            AIPromptField(controller: _aiPromptController),

            const SizedBox(height: 30),
            NextStepButton(
              onPressed: () {
                _generateTrip();
              },
            ),
          ],
        ),
      ),
    );
  }
}
