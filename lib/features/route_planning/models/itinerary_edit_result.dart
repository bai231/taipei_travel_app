import 'itinerary_edit_command.dart';

class ItineraryEditResult {
  /// Gemini 是否成功理解使用者的要求。
  final bool understood;

  /// 解析出來的修改指令。
  final List<ItineraryEditCommand> commands;

  /// 顯示給使用者看的修改摘要。
  final String summary;

  /// 資訊不足時，請使用者補充的問題。
  final String? clarificationQuestion;

  const ItineraryEditResult({
    required this.understood,
    required this.commands,
    required this.summary,
    this.clarificationQuestion,
  });

  Map<String, dynamic> toJson() {
    return {
      'understood': understood,
      'commands': commands.map((command) => command.toJson()).toList(),
      'summary': summary,
      'clarificationQuestion': clarificationQuestion,
    };
  }

  factory ItineraryEditResult.fromJson(Map<String, dynamic> json) {
    final rawCommands = json['commands'];

    final commands = rawCommands is List
        ? rawCommands
              .whereType<Map>()
              .map(
                (item) => ItineraryEditCommand.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <ItineraryEditCommand>[];

    final clarificationQuestion = _readString(json['clarificationQuestion']);

    return ItineraryEditResult(
      understood: json['understood'] == true,
      commands: commands,
      summary: _readString(json['summary']) ?? '',
      clarificationQuestion: clarificationQuestion,
    );
  }

  static String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool get needsClarification {
    return !understood || commands.isEmpty || clarificationQuestion != null;
  }

  bool get canApply {
    return understood && commands.isNotEmpty && clarificationQuestion == null;
  }
}
