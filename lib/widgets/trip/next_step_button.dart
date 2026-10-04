import 'package:flutter/material.dart';
import '../../services/language_service.dart';

class NextStepButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const NextStepButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward),
        label: Text(
          isLoading
              ? LanguageService.tr(context, 'trip_understanding_preferences')
              : LanguageService.tr(context, 'trip_next_step'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
