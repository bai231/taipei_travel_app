import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weather_alternative_strategy.dart';
import 'weather_advisory_service.dart';

class WeatherAlternativeException implements Exception {
  final String message;
  final bool retryable;

  const WeatherAlternativeException(this.message, {this.retryable = false});

  @override
  String toString() => message;
}

class WeatherAlternativeService {
  final SupabaseClient _client;

  WeatherAlternativeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<WeatherAlternativeStrategy> generate(
    WeatherIndoorItineraryRequest request,
  ) async {
    if (request.affectedPlaces.isEmpty) {
      throw const WeatherAlternativeException('目前沒有需要產生備案的景點');
    }

    try {
      final response = await _client.functions
          .invoke(
            'generate-weather-alternative',
            body: {'request': request.toJson()},
          )
          .timeout(const Duration(seconds: 90));

      final data = response.data;

      if (data is! Map) {
        throw const WeatherAlternativeException('AI 備案回傳格式不正確');
      }

      final responseJson = Map<String, dynamic>.from(data);
      final error = responseJson['error'];

      if (error is String && error.trim().isNotEmpty) {
        throw WeatherAlternativeException(
          error,
          retryable: responseJson['retryable'] == true,
        );
      }

      final strategyJson = responseJson['strategy'];

      if (strategyJson is! Map) {
        throw const WeatherAlternativeException('AI 回傳內容缺少 strategy');
      }

      final strategy = WeatherAlternativeStrategy.fromJson(
        Map<String, dynamic>.from(strategyJson),
      );

      if (!strategy.canContinue) {
        throw const WeatherAlternativeException('AI 無法產生有效的備案策略');
      }

      return strategy;
    } on TimeoutException {
      throw const WeatherAlternativeException(
        'AI 產生備案逾時，請稍後再試',
        retryable: true,
      );
    } on WeatherAlternativeException {
      rethrow;
    } catch (error) {
      final message = error.toString();
      final retryable =
          message.contains('429') ||
          message.contains('503') ||
          message.toLowerCase().contains('high demand');

      throw WeatherAlternativeException(
        retryable ? 'AI 目前使用量較高，請稍後再試' : '無法產生天氣備案：$error',
        retryable: retryable,
      );
    }
  }
}
