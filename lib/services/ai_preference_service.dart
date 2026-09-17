import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/travel_preference.dart';

class AiPreferenceException implements Exception {
  final String message;

  const AiPreferenceException(this.message);

  @override
  String toString() => message;
}

class AiPreferenceService {
  AiPreferenceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<TravelPreference> parsePreference(String text) async {
    final normalizedText = text.trim();

    if (normalizedText.isEmpty) {
      throw const AiPreferenceException('請先輸入旅遊偏好');
    }

    try {
      final response = await _client.functions
          .invoke('parse-travel-preference', body: {'text': normalizedText})
          .timeout(const Duration(seconds: 30));

      final data = response.data;

      if (data is! Map) {
        throw const AiPreferenceException('AI 回傳格式不正確');
      }

      final responseJson = Map<String, dynamic>.from(data);

      final error = responseJson['error'];

      if (error is String && error.isNotEmpty) {
        throw AiPreferenceException(error);
      }

      final preferenceJson = responseJson['preference'];

      if (preferenceJson is! Map) {
        throw const AiPreferenceException('AI 回傳內容缺少 preference 欄位');
      }

      return TravelPreference.fromJson(
        Map<String, dynamic>.from(preferenceJson),
      );
    } on TimeoutException {
      throw const AiPreferenceException('AI 回應逾時，請稍後再試');
    } on AiPreferenceException {
      rethrow;
    } catch (error) {
      throw AiPreferenceException('無法解析旅遊偏好：$error');
    }
  }
}
