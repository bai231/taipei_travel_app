import 'package:flutter/material.dart';

class NextStepButton extends StatelessWidget {
  final VoidCallback onPressed;

  const NextStepButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,

      height: 55,

      child: ElevatedButton.icon(
        onPressed: onPressed,

        icon: const Icon(Icons.arrow_forward),

        label: const Text("下一步", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
