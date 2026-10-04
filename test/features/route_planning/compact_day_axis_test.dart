import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/features/route_planning/models/compact_day_axis.dart';

void main() {
  test(
    'empty runs collapse but occupied hours and exact boundaries remain',
    () {
      final bands = compactDayBands(
        endHour: 24,
        visits: [(start: 540, end: 630)],
        hourHeight: 90,
        gapHeight: 48,
      );
      expect(bands.first.collapsed, isTrue);
      expect(bands.first.endHour, 9);
      expect(compactMinuteOffset(bands, 540), 48);
      expect(
        compactMinuteOffset(bands, 630) - compactMinuteOffset(bands, 540),
        135,
      );
      expect(bands.last.endHour, 24);
    },
  );
  test(
    'expanded gap restores real hourly drop targets including past midnight',
    () {
      final bands = compactDayBands(
        endHour: 26,
        visits: [(start: 1500, end: 1560)],
        hourHeight: 90,
        gapHeight: 48,
        expandedHours: {9, 10, 11},
      );
      expect(bands.where((b) => b.startHour == 10).single.collapsed, isFalse);
      expect(
        compactMinuteOffset(bands, 1560) - compactMinuteOffset(bands, 1500),
        90,
      );
      final all = compactDayBands(
        endHour: 24,
        visits: [],
        hourHeight: 90,
        gapHeight: 48,
        expandAll: true,
      );
      expect(all.length, 24);
      expect(all.any((b) => b.collapsed), isFalse);
    },
  );

  test('only leading and trailing empty time collapses', () {
    final bands = compactDayBands(
      endHour: 24,
      visits: [(start: 9 * 60, end: 10 * 60), (start: 15 * 60, end: 16 * 60)],
      hourHeight: 90,
      gapHeight: 48,
    );
    expect(bands.first.collapsed, isTrue);
    expect(bands.first.endHour, 9);
    for (var hour = 10; hour < 15; hour++) {
      expect(
        bands.singleWhere((band) => band.startHour == hour).collapsed,
        isFalse,
      );
    }
    expect(bands.last.collapsed, isTrue);
    expect(bands.last.startHour, 16);
    expect(
      compactMinuteOffset(bands, 15 * 60) - compactMinuteOffset(bands, 10 * 60),
      5 * 90,
    );
  });
}
