import '../models/place.dart';
import 'weather_advisory_service.dart';

enum WeatherExposure { indoor, mixed, outdoor }

class WeatherPlaceImpact {
  final Place place;
  final WeatherExposure exposure;
  final List<WeatherAdvisory> advisories;
  final List<String> reasons;

  const WeatherPlaceImpact({
    required this.place,
    required this.exposure,
    required this.advisories,
    required this.reasons,
  });

  bool get requiresAlternative => advisories.isNotEmpty;
}

class WeatherItineraryImpactAnalyzer {
  static const _indoorCategories = <String>{'藝文場館類', '觀光工廠類', '娛樂場館類', '生態場館類'};

  static const _outdoorCategories = <String>{
    '自然風景類',
    '國家自然公園類',
    '國家風景區類',
    '生態類',
    '休閒農業類',
    '都會公園類',
    '公園綠地類',
    '水域環境類',
    '森林遊樂區類',
    '國家公園類',
    '平地森林園區類',
    '觀光遊樂業類',
  };

  static const _indoorTags = <String>{'室內景點', '博物館', '藝文展覽', '觀光工廠', '休閒娛樂'};

  static const _outdoorTags = <String>{
    '戶外景點',
    '自然景觀',
    '登山健行',
    '森林',
    '海景',
    '風景區',
    '自行車',
    '休閒農業',
    '地質景觀',
    '自然生態',
    '戲水',
    '賞花',
    '溪流',
    '公園綠地',
    '湖泊',
    '濕地',
    '夕陽',
    '吊橋',
    '賞鳥',
    '瀑布',
    '日出',
    '賞櫻',
    '賞蝶',
    '森林浴',
    '水域景觀',
    '賞楓',
    '螢火蟲',
    '草原',
    '露營',
    '巨木',
    '雲海',
    '夜景',
    '觀星',
    '森林遊樂區',
    '賞鯨',
    '賞雪',
  };

  List<WeatherPlaceImpact> analyze({
    required Iterable<Place> places,
    required Iterable<WeatherAdvisory> advisories,
  }) {
    final currentAdvisories = advisories.toList(growable: false);
    final results = <WeatherPlaceImpact>[];

    for (final place in places) {
      // 餐廳與住宿暫時不列入天氣替換對象。
      if (place.type != PlaceType.attraction) continue;

      final exposure = classify(place);
      final affectingAdvisories = <WeatherAdvisory>[];
      final reasons = <String>[];

      for (final advisory in currentAdvisories) {
        if (!_isAffected(exposure, advisory)) continue;

        affectingAdvisories.add(advisory);
        reasons.add(_reasonFor(exposure, advisory));
      }

      if (affectingAdvisories.isEmpty) continue;

      results.add(
        WeatherPlaceImpact(
          place: place,
          exposure: exposure,
          advisories: List.unmodifiable(affectingAdvisories),
          reasons: List.unmodifiable(reasons),
        ),
      );
    }

    return List.unmodifiable(results);
  }

  WeatherExposure classify(Place place) {
    final category = place.category.trim();
    final tags = place.tags.map((tag) => tag.trim()).toSet();

    final hasIndoorEvidence =
        _indoorCategories.contains(category) || tags.any(_indoorTags.contains);

    final hasOutdoorEvidence =
        _outdoorCategories.contains(category) ||
        tags.any(_outdoorTags.contains);

    if (hasIndoorEvidence && hasOutdoorEvidence) {
      return WeatherExposure.mixed;
    }

    if (hasIndoorEvidence) {
      return WeatherExposure.indoor;
    }

    if (hasOutdoorEvidence) {
      return WeatherExposure.outdoor;
    }

    // 無法確定時使用 mixed，避免直接將景點判定成戶外。
    return WeatherExposure.mixed;
  }

  bool _isAffected(WeatherExposure exposure, WeatherAdvisory advisory) {
    if (exposure == WeatherExposure.indoor) {
      return false;
    }

    switch (advisory.kind) {
      case 'storm':
        // 雷雨會影響戶外與半戶外景點。
        return true;

      case 'rain':
        // 一般降雨影響戶外景點；
        // 嚴重降雨也會影響半戶外景點。
        return exposure == WeatherExposure.outdoor ||
            advisory.level == WeatherRiskLevel.severe;

      case 'uv':
        // 紫外線主要影響長時間戶外景點。
        return exposure == WeatherExposure.outdoor;

      case 'heat':
        // 目前只有嚴重高溫才觸發景點備案。
        return exposure == WeatherExposure.outdoor &&
            advisory.level == WeatherRiskLevel.severe;

      default:
        return false;
    }
  }

  String _reasonFor(WeatherExposure exposure, WeatherAdvisory advisory) {
    final exposureText = switch (exposure) {
      WeatherExposure.indoor => '室內',
      WeatherExposure.mixed => '半戶外',
      WeatherExposure.outdoor => '戶外',
    };

    return '$exposureText景點可能受到「${advisory.title}」影響';
  }
}
