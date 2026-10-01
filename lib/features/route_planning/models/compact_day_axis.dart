/// Display-only axis. Drop targets retain their original hour, never infer time
/// from compressed pixels. Only empty time before the first visit and after
/// the last visit can be collapsed; gaps between visits remain drop targets.
class CompactDayBand {
  final int startHour, endHour;
  final double top, height;
  final bool collapsed;
  const CompactDayBand(
    this.startHour,
    this.endHour,
    this.top,
    this.height,
    this.collapsed,
  );
}

List<CompactDayBand> compactDayBands({
  required int endHour,
  required List<({int start, int end})> visits,
  required double hourHeight,
  required double gapHeight,
  Set<int> expandedHours = const {},
  bool expandAll = false,
}) {
  final occupied = visits.where(
    (visit) => visit.end > 0 && visit.start < endHour * 60,
  );
  final firstOccupiedHour = occupied.isEmpty
      ? endHour
      : occupied
            .map((visit) => visit.start ~/ 60)
            .reduce((a, b) => a < b ? a : b);
  final lastOccupiedHour = occupied.isEmpty
      ? 0
      : occupied
            .map((visit) => (visit.end / 60).ceil())
            .reduce((a, b) => a > b ? a : b);
  bool empty(int hour) =>
      (hour < firstOccupiedHour || hour >= lastOccupiedHour) &&
      !expandedHours.contains(hour) &&
      !visits.any((v) => v.start < (hour + 1) * 60 && v.end > hour * 60);
  final bands = <CompactDayBand>[];
  var hour = 0;
  var top = 0.0;
  while (hour < endHour) {
    var end = hour + 1;
    if (!expandAll && empty(hour)) {
      while (end < endHour && empty(end)) {
        end++;
      }
    }
    final collapsed = end - hour >= 2;
    final height = collapsed ? gapHeight : hourHeight;
    bands.add(CompactDayBand(hour, end, top, height, collapsed));
    top += height;
    hour = end;
  }
  return bands;
}

double compactMinuteOffset(List<CompactDayBand> bands, int minutes) {
  for (final band in bands) {
    if (minutes < band.endHour * 60) {
      return band.top +
          (minutes - band.startHour * 60) /
              ((band.endHour - band.startHour) * 60) *
              band.height;
    }
  }
  return bands.isEmpty ? 0 : bands.last.top + bands.last.height;
}
