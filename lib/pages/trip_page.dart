import 'package:flutter/material.dart';
import '../widgets/trip/trip_date_field.dart';
import '../widgets/trip/people_counter.dart';
import '../widgets/trip/trip_name_field.dart';
import '../widgets/trip/budget_field.dart';
import '../widgets/trip/preference_chip_group.dart';
import '../widgets/trip/ai_prompt_field.dart';
import '../widgets/trip/next_step_button.dart';
import '../widgets/trip/trip_location_field.dart';
import '../models/trip_request.dart';
import '../services/place_service.dart';
import 'trip_planner_page.dart';
import '../services/ai_preference_service.dart';
import '../models/travel_preference.dart';
import '../models/travel_clarification.dart';
import '../services/recommendation/travel_clarification_service.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  final PlaceService _placeService = PlaceService();

  final AiPreferenceService _aiPreferenceService = AiPreferenceService();

  final TravelClarificationService _clarificationService =
      const TravelClarificationService();

  bool _isSubmitting = false;
  final TextEditingController _tripNameController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  int _people = 1;

  int? _budgetLevel;

  String _location = '台北市';

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

  Future<TravelPreference> _clarifyPreference(
    TravelPreference preference,
  ) async {
    final questions = _clarificationService.createQuestions(preference);

    if (questions.isEmpty || !mounted) {
      return preference;
    }

    final answers = <TravelClarificationType, String>{
      for (final question in questions) question.type: question.defaultValue,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.help_outline),
              title: const Text('再確認一些旅遊需求'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 520,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '以下資訊沒有出現在你的文字需求中，'
                        '確認後可以讓推薦結果更符合你的習慣。',
                      ),
                      const SizedBox(height: 16),

                      for (final question in questions) ...[
                        Text(
                          question.question,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),

                        for (final option in question.options)
                          RadioListTile<String>(
                            value: option.value,
                            groupValue: answers[question.type],
                            contentPadding: EdgeInsets.zero,
                            title: Text(option.label),
                            subtitle: Text(option.description),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setDialogState(() {
                                answers[question.type] = value;
                              });
                            },
                          ),

                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('使用預設值'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('套用選擇'),
                ),
              ],
            );
          },
        );
      },
    );

    // 使用者選擇使用預設值時，保留 Gemini 原本結果。
    if (confirmed != true) {
      return preference;
    }

    var updatedPreference = preference;

    for (final question in questions) {
      final answer = answers[question.type];

      if (answer == null) {
        continue;
      }

      switch (question.type) {
        case TravelClarificationType.pace:
          updatedPreference = updatedPreference.copyWith(
            pace: answer,
            paceSpecified: true,
          );

        case TravelClarificationType.walkingPreference:
          updatedPreference = updatedPreference.copyWith(
            walkingPreference: answer,
            walkingPreferenceSpecified: true,
          );
      }
    }

    return updatedPreference;
  }

  Future<void> _generateTrip() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先選擇旅遊日期")));

      return;
    }

    if (_budgetLevel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請選擇預算等級")));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final aiPrompt = _aiPromptController.text.trim();

      TravelPreference? parsedPreference;

      // 使用者有輸入其他需求時，才呼叫 Gemini。
      if (aiPrompt.isNotEmpty) {
        parsedPreference = await _aiPreferenceService.parsePreference(aiPrompt);

        if (!mounted) {
          return;
        }

        parsedPreference = await _clarifyPreference(parsedPreference);

        if (!mounted) {
          return;
        }
      }

      final request = TripRequest(
        title: _tripNameController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        location: _location,
        people: _people,
        budget_level: _budgetLevel!,
        preferences: _preferences,
        aiPrompt: aiPrompt,
        parsedPreference: parsedPreference,
      );

      final places = await _placeService.getTripCatalog();

      if (!mounted) {
        return;
      }

      if (places.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目前沒有可讀取的行程資料')));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TripPlannerPage(request: request, places: places),
        ),
      );
    } on AiPreferenceException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 偏好解析失敗：${error.message}')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('建立行程失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
            BudgetField(
              value: _budgetLevel,
              onChanged: (value) {
                setState(() {
                  _budgetLevel = value;
                });
              },
            ),

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
            NextStepButton(isLoading: _isSubmitting, onPressed: _generateTrip),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }
}
