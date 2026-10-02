class TravelPreference {
  final List<String> preferredCategories;
  final List<String> preferredTags;
  final List<String> excludedCategories;
  final List<String> excludedTags;
  final List<String> mustVisitPlaceNames;

  /// relaxed、balanced、intensive
  final String pace;

  /// 使用者是否在自然語言中明確提到行程節奏
  final bool paceSpecified;

  /// low、medium、high
  final String walkingPreference;

  /// 使用者是否在自然語言中明確提到步行需求
  final bool walkingPreferenceSpecified;

  /// 使用者在文字中提到的每日預算。
  /// 這不會覆蓋 TripRequest 中的行程總預算。
  final int? dailyBudget;

  final List<String> specialRequirements;
  final String summary;

  const TravelPreference({
    required this.preferredCategories,
    required this.preferredTags,
    required this.excludedCategories,
    required this.excludedTags,
    required this.mustVisitPlaceNames,
    required this.pace,
    required this.walkingPreference,
    required this.dailyBudget,
    required this.specialRequirements,
    required this.summary,
    this.paceSpecified = false,
    this.walkingPreferenceSpecified = false,
  });

  factory TravelPreference.fromJson(Map<String, dynamic> json) {
    return TravelPreference(
      preferredCategories: _readStringList(json['preferredCategories']),
      preferredTags: _readStringList(json['preferredTags']),
      excludedCategories: _readStringList(json['excludedCategories']),
      excludedTags: _readStringList(json['excludedTags']),
      mustVisitPlaceNames: _readStringList(json['mustVisitPlaceNames']),
      pace: _readPace(json['pace']),
      paceSpecified: _readBool(json['paceSpecified']),
      walkingPreference: _readWalkingPreference(json['walkingPreference']),
      walkingPreferenceSpecified: _readBool(json['walkingPreferenceSpecified']),
      dailyBudget: _readNullableInt(json['dailyBudget']),
      specialRequirements: _readStringList(json['specialRequirements']),
      summary: json['summary'] is String
          ? (json['summary'] as String).trim()
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredCategories': preferredCategories,
      'preferredTags': preferredTags,
      'excludedCategories': excludedCategories,
      'excludedTags': excludedTags,
      'mustVisitPlaceNames': mustVisitPlaceNames,
      'pace': pace,
      'paceSpecified': paceSpecified,
      'walkingPreference': walkingPreference,
      'walkingPreferenceSpecified': walkingPreferenceSpecified,
      'dailyBudget': dailyBudget,
      'specialRequirements': specialRequirements,
      'summary': summary,
    };
  }

  TravelPreference copyWith({
    String? pace,
    bool? paceSpecified,
    String? walkingPreference,
    bool? walkingPreferenceSpecified,
  }) {
    return TravelPreference(
      preferredCategories: preferredCategories,
      preferredTags: preferredTags,
      excludedCategories: excludedCategories,
      excludedTags: excludedTags,
      mustVisitPlaceNames: mustVisitPlaceNames,
      pace: pace ?? this.pace,
      paceSpecified: paceSpecified ?? this.paceSpecified,
      walkingPreference: walkingPreference ?? this.walkingPreference,
      walkingPreferenceSpecified:
          walkingPreferenceSpecified ?? this.walkingPreferenceSpecified,
      dailyBudget: dailyBudget,
      specialRequirements: specialRequirements,
      summary: summary,
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return List<String>.unmodifiable(
      value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }

  static String _readPace(dynamic value) {
    const allowedValues = {'relaxed', 'balanced', 'intensive'};

    if (value is String && allowedValues.contains(value)) {
      return value;
    }

    return 'balanced';
  }

  static String _readWalkingPreference(dynamic value) {
    const allowedValues = {'low', 'medium', 'high'};

    if (value is String && allowedValues.contains(value)) {
      return value;
    }

    return 'medium';
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }

    return false;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
