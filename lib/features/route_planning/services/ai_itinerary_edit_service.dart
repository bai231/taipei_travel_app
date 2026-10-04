import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/itinerary_edit_result.dart';
import '../models/route_itinerary.dart';
import 'itinerary_ai_summary_builder.dart';

class AiItineraryEditException implements Exception {
  final String message;

  const AiItineraryEditException(this.message);

  @override
  String toString() => message;
}

class AiItineraryEditService {
  AiItineraryEditService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ItineraryEditResult> parseEdit({
    required String text,
    required RouteItinerary itinerary,
  }) async {
    final normalizedText = text.trim();

    if (normalizedText.isEmpty) {
      throw const AiItineraryEditException('請先輸入想修改的內容');
    }

    final itinerarySummary = ItineraryAiSummaryBuilder.build(itinerary);

    try {
      final response = await _client.functions
          .invoke(
            'parse-itinerary-edit',
            body: {'text': normalizedText, 'itinerary': itinerarySummary},
          )
          .timeout(const Duration(seconds: 90));

      final data = response.data;

      if (data is! Map) {
        throw const AiItineraryEditException('AI 回傳格式不正確');
      }

      final responseJson = Map<String, dynamic>.from(data);

      final error = responseJson['error'];

      if (error is String && error.trim().isNotEmpty) {
        throw AiItineraryEditException(error);
      }

      final resultJson = responseJson['result'];

      if (resultJson is! Map) {
        throw const AiItineraryEditException('AI 回傳內容缺少 result 欄位');
      }

      return ItineraryEditResult.fromJson(
        Map<String, dynamic>.from(resultJson),
      );
    } on TimeoutException {
      throw const AiItineraryEditException('AI 回應逾時，請稍後再試');
    } on AiItineraryEditException {
      rethrow;
    } catch (error) {
      final message = error.toString();

      if (message.contains('503') ||
          message.contains('high demand') ||
          message.contains('Service Unavailable')) {
        throw const AiItineraryEditException('AI 目前使用人數較多，請稍後再試');
      }

      throw AiItineraryEditException('無法理解行程修改要求：$error');
    }
  }
}
