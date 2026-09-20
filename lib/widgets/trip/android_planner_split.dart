import 'package:flutter/material.dart';

/// Dragging the divider changes panel space; scrolling inside stays independent.
class AndroidPlannerSplit extends StatefulWidget {
  final Widget timeline;
  final Widget unscheduled;
  const AndroidPlannerSplit({
    super.key,
    required this.timeline,
    required this.unscheduled,
  });
  @override
  State<AndroidPlannerSplit> createState() => _AndroidPlannerSplitState();
}

class _AndroidPlannerSplitState extends State<AndroidPlannerSplit> {
  double _fraction = 0.5;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final space = (constraints.maxHeight - 40).clamp(0.0, double.infinity);
      return Column(
        children: [
          SizedBox(height: space * (1 - _fraction), child: widget.timeline),
          Semantics(
            label: '調整不限日期時間區域高度',
            onIncrease: () =>
                setState(() => _fraction = (_fraction + 0.1).clamp(0.2, 0.8)),
            onDecrease: () =>
                setState(() => _fraction = (_fraction - 0.1).clamp(0.2, 0.8)),
            child: GestureDetector(
              key: const ValueKey('unscheduled-resize-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                if (space <= 0) return;
                setState(
                  () => _fraction = (_fraction - details.delta.dy / space)
                      .clamp(0.2, 0.8),
                );
              },
              child: const SizedBox(
                height: 40,
                width: double.infinity,
                child: Center(child: Icon(Icons.drag_handle)),
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('unscheduled-resizable-panel'),
            height: space * _fraction,
            child: widget.unscheduled,
          ),
        ],
      );
    },
  );
}
