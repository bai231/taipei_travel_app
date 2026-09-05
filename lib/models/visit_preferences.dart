import 'place.dart';

enum MealType {
  unspecified('未指定餐別', null, null, 60),
  breakfast('早餐', 420, 600, 45),
  lunch('午餐', 660, 840, 60),
  dinner('晚餐', 1020, 1230, 90),
  snack('咖啡／點心', null, null, 45);

  final String label;
  final int? startMinutes;
  final int? endMinutes;
  final int durationMinutes;

  const MealType(
    this.label,
    this.startMinutes,
    this.endMinutes,
    this.durationMinutes,
  );
}

enum VisitKind {
  activity('一般活動'),
  hotelStay('住宿');

  final String label;
  const VisitKind(this.label);
}

class HotelStay {
  final int checkInDay;
  final int checkOutDay;
  final int? checkInFromMinutes;

  const HotelStay({
    required this.checkInDay,
    required this.checkOutDay,
    this.checkInFromMinutes,
  });

  int get effectiveCheckInFrom => checkInFromMinutes ?? 900;
}

class VisitPreferences {
  final MealType mealType;
  final int? durationMinutes;
  final int? mealWindowStart;
  final int? mealWindowEnd;
  final HotelStay? hotelStay;

  const VisitPreferences({
    this.mealType = MealType.unspecified,
    this.durationMinutes,
    this.mealWindowStart,
    this.mealWindowEnd,
    this.hotelStay,
  });

  int durationFor(Place place, {MealType? suggestedMealType}) {
    if (durationMinutes != null) return durationMinutes!;
    return switch (place.type) {
      PlaceType.restaurant =>
        (mealType == MealType.unspecified
                ? suggestedMealType ?? mealType
                : mealType)
            .durationMinutes,
      PlaceType.accommodation => 30,
      PlaceType.attraction => place.stayTime,
    };
  }

  String? validationError(Place place, int tripDays) {
    if (durationMinutes != null &&
        (durationMinutes! < 1 || durationMinutes! > 1440)) {
      return '停留時間必須介於 1 至 1440 分鐘。';
    }
    if ((mealWindowStart == null) != (mealWindowEnd == null)) {
      return '用餐時段需同時設定開始與結束時間。';
    }
    if (mealWindowStart != null &&
        (mealWindowStart! < 0 ||
            mealWindowEnd! > 1440 ||
            mealWindowStart! > mealWindowEnd!)) {
      return '用餐開始時段必須介於 00:00 至 24:00，且結束不得早於開始。';
    }
    if (place.type != PlaceType.accommodation) return null;
    final stay = hotelStay;
    if (stay == null) return null;
    if (stay.checkInDay < 1 ||
        stay.checkInDay > tripDays ||
        stay.checkOutDay <= stay.checkInDay ||
        stay.checkOutDay > tripDays + 1) {
      return '住宿日期必須在旅程內，住宿結束日晚於開始日；最晚可到旅程結束隔日。';
    }
    for (final time in [stay.checkInFromMinutes]) {
      if (time != null && (time < 0 || time >= 1440)) {
        return '最早抵達飯店時間須介於 00:00 至 23:59。';
      }
    }
    return null;
  }

  String summaryFor(Place place) {
    if (place.type == PlaceType.accommodation) {
      final stay = hotelStay;
      return stay == null
          ? '系統自動安排住宿日期・每日最後一站'
          : 'Day ${stay.checkInDay} 起住宿至 Day ${stay.checkOutDay}・每日最後一站';
    }
    return '${place.type == PlaceType.restaurant ? '${mealType.label}・' : ''}'
        '${durationFor(place)} 分鐘（${durationMinutes == null ? '預估' : '使用者設定'}）';
  }
}
