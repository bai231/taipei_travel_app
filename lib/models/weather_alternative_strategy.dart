enum WeatherAlternativeDecision {
  replace,
  keep;

  static WeatherAlternativeDecision fromJson(Object? value) {
    return value == 'replace'
        ? WeatherAlternativeDecision.replace
        : WeatherAlternativeDecision.keep;
  }
}

class WeatherAlternativeReplacement {
  final String targetOccurrenceId;
  final WeatherAlternativeDecision decision;
  final List<String> preferredCategories;
  final List<String> preferredTags;
  final List<String> excludedTags;
  final String? preferredCounty;
  final int maxTravelMinutes;
  final String reason;

  const WeatherAlternativeReplacement({
    required this.targetOccurrenceId,
    required this.decision,
    required this.preferredCategories,
    required this.preferredTags,
    required this.excludedTags,
    required this.preferredCounty,
    required this.maxTravelMinutes,
    required this.reason,
  });

  factory WeatherAlternativeReplacement.fromJson(Map<String, dynamic> json) {
    return WeatherAlternativeReplacement(
      targetOccurrenceId: json['targetOccurrenceId']?.toString() ?? '',
      decision: WeatherAlternativeDecision.fromJson(json['decision']),
      preferredCategories: _stringList(json['preferredCategories']),
      preferredTags: _stringList(json['preferredTags']),
      excludedTags: _stringList(json['excludedTags']),
      preferredCounty: _nullableString(json['preferredCounty']),
      maxTravelMinutes: (json['maxTravelMinutes'] as num?)?.toInt() ?? 30,
      reason: json['reason']?.toString() ?? '',
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _nullableString(Object? value) {
    if (value is! String) return null;

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class WeatherAlternativeStrategy {
  final bool understood;
  final List<WeatherAlternativeReplacement> replacements;
  final String summary;

  const WeatherAlternativeStrategy({
    required this.understood,
    required this.replacements,
    required this.summary,
  });

  factory WeatherAlternativeStrategy.fromJson(Map<String, dynamic> json) {
    final rawReplacements = json['replacements'];

    final replacements = rawReplacements is List
        ? rawReplacements
              .whereType<Map>()
              .map(
                (item) => WeatherAlternativeReplacement.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <WeatherAlternativeReplacement>[];

    return WeatherAlternativeStrategy(
      understood: json['understood'] == true,
      replacements: replacements,
      summary: json['summary']?.toString() ?? '',
    );
  }

  bool get canContinue => understood && replacements.isNotEmpty;
}
