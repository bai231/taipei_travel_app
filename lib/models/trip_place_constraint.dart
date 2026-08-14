import 'place.dart';

class TripPlaceConstraint {
  final Place place;

  // 使用者指定的日期
  // null = 不限日期
  int? day;

  // 使用者指定的開始時間
  // null = 不限時間
  int? startMinutes;

  // 是否鎖定
  // true = 系統不能更改這個景點的時間
  bool locked;

  TripPlaceConstraint({
    required this.place,
    this.day,
    this.startMinutes,
    this.locked = false,
  });
}
