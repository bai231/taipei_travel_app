import '../../models/travel_clarification.dart';
import '../../models/travel_preference.dart';

class TravelClarificationService {
  const TravelClarificationService();

  List<TravelClarification> createQuestions(TravelPreference? preference) {
    // 沒有使用 AI 輸入時，維持原本系統預設值，
    // 不主動要求使用者回答額外問題。
    if (preference == null) {
      return const [];
    }

    final questions = <TravelClarification>[];

    if (!preference.paceSpecified) {
      questions.add(_paceQuestion);
    }

    if (!preference.walkingPreferenceSpecified) {
      questions.add(_walkingQuestion);
    }

    return List.unmodifiable(questions);
  }

  static const TravelClarification _paceQuestion = TravelClarification(
    type: TravelClarificationType.pace,
    question: '你希望行程安排得多緊湊？',
    defaultValue: 'balanced',
    options: [
      TravelClarificationOption(
        value: 'relaxed',
        label: '悠閒',
        description: '每天安排較少景點，保留更多休息時間',
      ),
      TravelClarificationOption(
        value: 'balanced',
        label: '適中',
        description: '景點數量與休息時間保持平衡',
      ),
      TravelClarificationOption(
        value: 'intensive',
        label: '緊湊',
        description: '每天安排較多景點，充分利用時間',
      ),
    ],
  );

  static const TravelClarification _walkingQuestion = TravelClarification(
    type: TravelClarificationType.walkingPreference,
    question: '你可以接受多少步行量？',
    defaultValue: 'medium',
    options: [
      TravelClarificationOption(
        value: 'low',
        label: '較少',
        description: '希望減少長距離步行',
      ),
      TravelClarificationOption(
        value: 'medium',
        label: '適中',
        description: '可以接受一般觀光行程的步行量',
      ),
      TravelClarificationOption(
        value: 'high',
        label: '較多',
        description: '可以接受長時間步行或健行',
      ),
    ],
  );
}
