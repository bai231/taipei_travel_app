import 'dart:convert';

class LocalPlaceRecord {
  final String id;
  final String name;
  final String address;
  final String category;
  final double? latitude;
  final double? longitude;
  final int? stayTime;
  final int? openMinutes;
  final int? closeMinutes;

  const LocalPlaceRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.stayTime,
    required this.openMinutes,
    required this.closeMinutes,
  });

  factory LocalPlaceRecord.fromJson(Map<String, dynamic> json) {
    return LocalPlaceRecord(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      stayTime: (json['stayTime'] as num?)?.toInt(),
      openMinutes: (json['openMinutes'] as num?)?.toInt(),
      closeMinutes: (json['closeMinutes'] as num?)?.toInt(),
    );
  }

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180 &&
      (latitude != 0 || longitude != 0);

  bool get needsData =>
      !hasValidCoordinates ||
      stayTime == null ||
      openMinutes == null ||
      closeMinutes == null;
}

class TdxServicePeriod {
  final String name;
  final String description;
  final List<String> serviceDays;
  final String startTime;
  final String endTime;
  final String effectiveDate;
  final String expireDate;

  const TdxServicePeriod({
    required this.name,
    required this.description,
    required this.serviceDays,
    required this.startTime,
    required this.endTime,
    required this.effectiveDate,
    required this.expireDate,
  });

  factory TdxServicePeriod.fromJson(Map<String, dynamic> json) {
    return TdxServicePeriod(
      name: json['Name']?.toString() ?? '',
      description: json['Description']?.toString() ?? '',
      serviceDays: (json['ServiceDays'] as List<dynamic>? ?? const [])
          .map((day) => day.toString())
          .toList(),
      startTime: json['StartTime']?.toString() ?? '',
      endTime: json['EndTime']?.toString() ?? '',
      effectiveDate: json['EffectiveDate']?.toString() ?? '',
      expireDate: json['ExpireDate']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'serviceDays': serviceDays,
      'startTime': startTime,
      'endTime': endTime,
      'effectiveDate': effectiveDate,
      'expireDate': expireDate,
    };
  }
}

class TdxAttractionRecord {
  final String id;
  final String name;
  final List<String> alternateNames;
  final String city;
  final String town;
  final String streetAddress;
  final double? latitude;
  final double? longitude;
  final int? visitDuration;
  final String serviceTimeInfo;
  final List<int> attractionClasses;
  final List<TdxServicePeriod> servicePeriods;

  const TdxAttractionRecord({
    required this.id,
    required this.name,
    required this.alternateNames,
    required this.city,
    required this.town,
    required this.streetAddress,
    required this.latitude,
    required this.longitude,
    required this.visitDuration,
    required this.serviceTimeInfo,
    required this.attractionClasses,
    required this.servicePeriods,
  });

  factory TdxAttractionRecord.fromJson(
    Map<String, dynamic> json, {
    List<TdxServicePeriod> servicePeriods = const [],
  }) {
    final postalAddress =
        json['PostalAddress'] as Map<String, dynamic>? ?? const {};
    return TdxAttractionRecord(
      id: json['AttractionID']?.toString() ?? '',
      name: json['AttractionName']?.toString() ?? '',
      alternateNames: (json['AlternateNames'] as List<dynamic>? ?? const [])
          .map((name) => name.toString())
          .toList(),
      city: postalAddress['City']?.toString() ?? '',
      town: postalAddress['Town']?.toString() ?? '',
      streetAddress: postalAddress['StreetAddress']?.toString() ?? '',
      latitude: (json['PositionLat'] as num?)?.toDouble(),
      longitude: (json['PositionLon'] as num?)?.toDouble(),
      visitDuration: (json['VisitDuration'] as num?)?.toInt(),
      serviceTimeInfo: json['ServiceTimeInfo']?.toString() ?? '',
      attractionClasses:
          (json['AttractionClasses'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((value) => value.toInt())
              .toList(),
      servicePeriods: servicePeriods,
    );
  }

  String get fullAddress => '$city$town$streetAddress';

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180 &&
      (latitude != 0 || longitude != 0);

  TdxAttractionRecord withServicePeriods(List<TdxServicePeriod> periods) {
    return TdxAttractionRecord(
      id: id,
      name: name,
      alternateNames: alternateNames,
      city: city,
      town: town,
      streetAddress: streetAddress,
      latitude: latitude,
      longitude: longitude,
      visitDuration: visitDuration,
      serviceTimeInfo: serviceTimeInfo,
      attractionClasses: attractionClasses,
      servicePeriods: periods,
    );
  }
}

enum MatchConfidence { high, review, unmatched }

class OpeningRange {
  final int openMinutes;
  final int closeMinutes;

  const OpeningRange({required this.openMinutes, required this.closeMinutes});
}

class PlaceMatchResult {
  final LocalPlaceRecord localPlace;
  final TdxAttractionRecord? attraction;
  final double score;
  final double margin;
  final MatchConfidence confidence;
  final String reason;
  final OpeningRange? representativeHours;
  final int proposedStayTime;
  final String stayTimeSource;

  const PlaceMatchResult({
    required this.localPlace,
    required this.attraction,
    required this.score,
    required this.margin,
    required this.confidence,
    required this.reason,
    required this.representativeHours,
    required this.proposedStayTime,
    required this.stayTimeSource,
  });

  bool get canAutoUpdate =>
      confidence == MatchConfidence.high &&
      attraction != null &&
      attraction!.hasValidCoordinates;

  Map<String, dynamic> toJson() {
    final matchedAttraction = attraction;
    return {
      'dbId': localPlace.id,
      'dbName': localPlace.name,
      'dbAddress': localPlace.address,
      'confidence': confidence.name,
      'score': double.parse(score.toStringAsFixed(4)),
      'margin': double.parse(margin.toStringAsFixed(4)),
      'reason': reason,
      'tdxAttractionId': matchedAttraction?.id,
      'tdxName': matchedAttraction?.name,
      'tdxAddress': matchedAttraction?.fullAddress,
      'latitude': matchedAttraction?.latitude,
      'longitude': matchedAttraction?.longitude,
      'visitDuration': matchedAttraction?.visitDuration,
      'proposedStayTime': proposedStayTime,
      'stayTimeSource': stayTimeSource,
      'serviceTimeInfo': matchedAttraction?.serviceTimeInfo,
      'servicePeriods': matchedAttraction?.servicePeriods
          .map((period) => period.toJson())
          .toList(),
      'proposedOpenMinutes': representativeHours?.openMinutes,
      'proposedCloseMinutes': representativeHours?.closeMinutes,
      'canAutoUpdate': canAutoUpdate,
    };
  }

  String servicePeriodsJson() {
    return jsonEncode(
      attraction?.servicePeriods.map((period) => period.toJson()).toList() ??
          const [],
    );
  }
}

class TdxPlaceMatcher {
  static const _counties = [
    '台北市',
    '新北市',
    '桃園市',
    '台中市',
    '台南市',
    '高雄市',
    '基隆市',
    '新竹市',
    '嘉義市',
    '新竹縣',
    '苗栗縣',
    '彰化縣',
    '南投縣',
    '雲林縣',
    '嘉義縣',
    '屏東縣',
    '宜蘭縣',
    '花蓮縣',
    '台東縣',
    '澎湖縣',
    '金門縣',
    '連江縣',
  ];

  final List<TdxAttractionRecord> attractions;
  late final Map<String, List<TdxAttractionRecord>> _byAddress;
  late final Map<String, List<TdxAttractionRecord>> _byName;
  late final Map<String, List<TdxAttractionRecord>> _byCity;

  TdxPlaceMatcher(this.attractions) {
    _byAddress = _groupBy(
      attractions,
      (attraction) => normalizeAddress(attraction.fullAddress),
    );
    _byName = _groupBy(
      attractions,
      (attraction) => normalizeName(attraction.name),
    );
    _byCity = _groupBy(
      attractions,
      (attraction) => normalizeText(attraction.city),
    );
  }

  PlaceMatchResult match(LocalPlaceRecord localPlace) {
    final normalizedAddress = normalizeAddress(localPlace.address);
    final normalizedName = normalizeName(localPlace.name);
    final city = extractCity(localPlace.address);
    final candidates = <TdxAttractionRecord>{};

    if (normalizedAddress.isNotEmpty) {
      candidates.addAll(_byAddress[normalizedAddress] ?? const []);
    }
    if (normalizedName.isNotEmpty) {
      candidates.addAll(_byName[normalizedName] ?? const []);
    }
    if (candidates.isEmpty && city.isNotEmpty) {
      candidates.addAll(_byCity[city] ?? const []);
    }
    if (candidates.isEmpty) {
      candidates.addAll(attractions);
    }

    final ranked =
        candidates.map((candidate) => _score(localPlace, candidate)).toList()
          ..sort((left, right) => right.score.compareTo(left.score));

    if (ranked.isEmpty || ranked.first.score < 0.68) {
      return _unmatched(localPlace);
    }

    final best = ranked.first;
    final secondScore = ranked.length > 1 ? ranked[1].score : 0.0;
    final margin = best.score - secondScore;
    final confidence = _confidence(best, margin);
    if (confidence == MatchConfidence.unmatched) {
      return _unmatched(localPlace);
    }

    final representativeHours = deriveRepresentativeHours(
      best.attraction.servicePeriods,
    );
    final tdxDuration = best.attraction.visitDuration;
    final proposedStayTime = tdxDuration != null && tdxDuration > 0
        ? tdxDuration
        : estimateStayTime(
            localPlace.name,
            localPlace.category,
            best.attraction.attractionClasses,
          );

    return PlaceMatchResult(
      localPlace: localPlace,
      attraction: best.attraction,
      score: best.score,
      margin: margin,
      confidence: confidence,
      reason: best.reason,
      representativeHours: representativeHours,
      proposedStayTime: proposedStayTime,
      stayTimeSource: tdxDuration != null && tdxDuration > 0
          ? 'tdx_visit_duration'
          : 'category_rule',
    );
  }

  PlaceMatchResult _unmatched(LocalPlaceRecord localPlace) {
    return PlaceMatchResult(
      localPlace: localPlace,
      attraction: null,
      score: 0,
      margin: 0,
      confidence: MatchConfidence.unmatched,
      reason: 'no_reliable_match',
      representativeHours: null,
      proposedStayTime: estimateStayTime(
        localPlace.name,
        localPlace.category,
        const [],
      ),
      stayTimeSource: 'category_rule',
    );
  }

  _ScoredAttraction _score(
    LocalPlaceRecord localPlace,
    TdxAttractionRecord attraction,
  ) {
    final localName = normalizeName(localPlace.name);
    final localAddress = normalizeAddress(localPlace.address);
    final tdxName = normalizeName(attraction.name);
    final tdxAddress = normalizeAddress(attraction.fullAddress);
    final localCity = extractCity(localPlace.address);
    final tdxCity = normalizeText(attraction.city);
    final nameScore = similarity(localName, tdxName);
    final addressScore = similarity(localAddress, tdxAddress);
    final exactName = localName.isNotEmpty && localName == tdxName;
    final exactAddress = localAddress.length >= 6 && localAddress == tdxAddress;
    final cityMatch = localCity.isNotEmpty && localCity == tdxCity;

    if (exactAddress && exactName) {
      return _ScoredAttraction(attraction, 1, 'exact_name_and_address');
    }
    if (exactAddress) {
      return _ScoredAttraction(
        attraction,
        0.94 + (0.05 * nameScore),
        'exact_address',
      );
    }
    if (exactName && cityMatch) {
      return _ScoredAttraction(
        attraction,
        0.9 + (0.08 * addressScore),
        'exact_name_same_city',
      );
    }

    final score =
        (nameScore * 0.52) + (addressScore * 0.43) + (cityMatch ? 0.05 : 0);
    return _ScoredAttraction(attraction, score, 'fuzzy_name_and_address');
  }

  MatchConfidence _confidence(_ScoredAttraction best, double margin) {
    if (!best.attraction.hasValidCoordinates) {
      return MatchConfidence.review;
    }
    if (best.reason != 'exact_name_and_address') {
      return best.score >= 0.78 && margin >= 0.03
          ? MatchConfidence.review
          : MatchConfidence.unmatched;
    }
    if (best.score >= 0.96 && margin >= 0.02) {
      return MatchConfidence.high;
    }
    if (best.score >= 0.9 && margin >= 0.05) {
      return MatchConfidence.high;
    }
    if (best.score >= 0.78 && margin >= 0.03) {
      return MatchConfidence.review;
    }
    return MatchConfidence.unmatched;
  }

  static Map<String, List<TdxAttractionRecord>> _groupBy(
    Iterable<TdxAttractionRecord> values,
    String Function(TdxAttractionRecord value) keyOf,
  ) {
    final grouped = <String, List<TdxAttractionRecord>>{};
    for (final value in values) {
      final key = keyOf(value);
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(value);
    }
    return grouped;
  }

  static String normalizeName(String value) {
    return normalizeText(value)
        .replaceAll(RegExp(r'[\(（][^\)）]*[\)）]'), '')
        .replaceAll('風景區', '')
        .replaceAll('遊憩區', '');
  }

  static String normalizeAddress(String value) {
    return normalizeText(value)
        .replaceFirst(RegExp(r'^\d{3,6}'), '')
        .replaceFirst('中華民國', '')
        .replaceFirst('台灣', '');
  }

  static String normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('臺', '台')
        .replaceAll('－', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[\s,，。．、;；:：/\\\-＿_\[\]【】]'), '');
  }

  static String extractCity(String address) {
    final normalized = normalizeText(address);
    for (final county in _counties) {
      if (normalized.contains(county)) return county;
    }
    return '';
  }

  static double similarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    final distance = _levenshtein(left, right);
    final longest = left.length > right.length ? left.length : right.length;
    return 1 - (distance / longest);
  }

  static int _levenshtein(String left, String right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 1; leftIndex <= left.length; leftIndex++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex;
      for (var rightIndex = 1; rightIndex <= right.length; rightIndex++) {
        final substitutionCost =
            left.codeUnitAt(leftIndex - 1) == right.codeUnitAt(rightIndex - 1)
            ? 0
            : 1;
        final deletion = previous[rightIndex] + 1;
        final insertion = current[rightIndex - 1] + 1;
        final substitution = previous[rightIndex - 1] + substitutionCost;
        current[rightIndex] = [
          deletion,
          insertion,
          substitution,
        ].reduce((minimum, value) => value < minimum ? value : minimum);
      }
      previous = current;
    }
    return previous[right.length];
  }

  static OpeningRange? deriveRepresentativeHours(
    List<TdxServicePeriod> periods,
  ) {
    final frequencies = <String, int>{};
    final ranges = <String, OpeningRange>{};
    for (final period in periods) {
      final openMinutes = parseTime(period.startTime);
      final closeMinutes = parseTime(period.endTime);
      if (openMinutes == null || closeMinutes == null) continue;
      if (closeMinutes <= openMinutes) continue;
      final key = '$openMinutes-$closeMinutes';
      frequencies[key] =
          (frequencies[key] ?? 0) +
          (period.serviceDays.isEmpty ? 1 : period.serviceDays.length);
      ranges[key] = OpeningRange(
        openMinutes: openMinutes,
        closeMinutes: closeMinutes,
      );
    }
    if (frequencies.isEmpty) return null;
    final bestKey = frequencies.entries.reduce((best, current) {
      return current.value > best.value ? current : best;
    }).key;
    return ranges[bestKey];
  }

  static int? parseTime(String value) {
    final segments = value.trim().split(':');
    final normalized = segments.length == 3
        ? '${segments[0]}:${segments[1]}'
        : value.trim();
    final digits = normalized.replaceAll(':', '');
    if (!RegExp(r'^\d{3,4}$').hasMatch(digits)) return null;
    final padded = digits.padLeft(4, '0');
    final hour = int.tryParse(padded.substring(0, 2));
    final minute = int.tryParse(padded.substring(2, 4));
    if (hour == null || minute == null) return null;
    if (hour > 24 || minute > 59 || (hour == 24 && minute != 0)) return null;
    return (hour * 60) + minute;
  }

  static int estimateStayTime(
    String name,
    String category,
    List<int> attractionClasses,
  ) {
    final text = normalizeText('$name$category');
    if (RegExp(r'博物館|美術館|紀念館|文物館|展覽館').hasMatch(text)) {
      return 120;
    }
    if (RegExp(r'寺|廟|宮|教堂|宗祠').hasMatch(text)) return 60;
    if (text.contains('夜市')) return 120;
    if (RegExp(r'步道|古道|登山|森林遊樂區').hasMatch(text)) return 150;
    if (RegExp(r'公園|園區|農場|牧場').hasMatch(text)) return 90;
    if (RegExp(r'老街|商圈|文創|聚落').hasMatch(text)) return 90;
    if (RegExp(r'瀑布|燈塔|觀景|景觀|地標').hasMatch(text)) return 60;
    if (attractionClasses.contains(16)) return 150;
    return 60;
  }
}

class _ScoredAttraction {
  final TdxAttractionRecord attraction;
  final double score;
  final String reason;

  const _ScoredAttraction(this.attraction, this.score, this.reason);
}
