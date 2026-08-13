class ScheduledVisit {
  final int departureMinutes;
  final int arrivalMinutes;
  final int visitStartMinutes;
  final int visitEndMinutes;
  final int waitingMinutes;
  final int stayMinutes;

  const ScheduledVisit({
    required this.departureMinutes,
    required this.arrivalMinutes,
    required this.visitStartMinutes,
    required this.visitEndMinutes,
    required this.waitingMinutes,
    required this.stayMinutes,
  });
}
