import 'package:flutter/foundation.dart';

// Explicit platform gate: narrow browser windows still use the Web layout.
bool get usesAndroidTripLayout =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
