import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/widgets/trip/android_planner_split.dart';

void main() {
  testWidgets(
    'divider resizes bounded panel without replacing list scrolling',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AndroidPlannerSplit(
              timeline: const Text('時間軸'),
              unscheduled: ListView(
                children: List.generate(
                  30,
                  (i) => SizedBox(height: 80, child: Text('景點 $i')),
                ),
              ),
            ),
          ),
        ),
      );
      final panel = find.byKey(const ValueKey('unscheduled-resizable-panel'));
      final handle = find.byKey(const ValueKey('unscheduled-resize-handle'));
      final initial = tester.getSize(panel).height;
      await tester.drag(handle, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, lessThan(initial));
      await tester.drag(handle, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, greaterThan(initial));
      final expanded = tester.getSize(panel).height;
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, expanded);
      expect(tester.takeException(), isNull);
    },
  );
}
