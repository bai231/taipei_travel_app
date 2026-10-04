import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CwaQueryTimeStore {
  Future<DateTime?> readLastAttempt();

  Future<void> writeLastAttempt(DateTime time);
}

/// Keeps the last attempted CWA request across itinerary and app restarts.
class SharedPreferencesCwaQueryTimeStore implements CwaQueryTimeStore {
  static const _key = 'cwa_weather_last_request_epoch_ms';
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _storage =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<DateTime?> readLastAttempt() async {
    final epochMs = await _storage.getInt(_key);
    return epochMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  @override
  Future<void> writeLastAttempt(DateTime time) =>
      _storage.setInt(_key, time.millisecondsSinceEpoch);
}

/// Reserves a request before it is sent, including unsuccessful HTTP attempts.
///
/// All production weather services share one instance so concurrent checks in
/// this Dart isolate cannot both pass the hour limit. The timestamp also lives
/// on disk, so starting a different itinerary does not reset the interval.
class CwaQueryLimiter {
  static final CwaQueryLimiter shared = CwaQueryLimiter(
    store: SharedPreferencesCwaQueryTimeStore(),
  );

  final CwaQueryTimeStore store;
  final Duration minimumInterval;
  Future<void> _previous = Future<void>.value();

  CwaQueryLimiter({
    required this.store,
    this.minimumInterval = const Duration(hours: 1),
  });

  Future<bool> reserve(DateTime now) async {
    final previous = _previous;
    final release = Completer<void>();
    _previous = release.future;
    await previous;
    try {
      final lastAttempt = await store.readLastAttempt();
      if (lastAttempt != null &&
          now.difference(lastAttempt) < minimumInterval) {
        return false;
      }
      // If persistence fails, do not send an unmetered CWA request.
      await store.writeLastAttempt(now);
      return true;
    } finally {
      release.complete();
    }
  }
}
