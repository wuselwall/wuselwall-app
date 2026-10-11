import 'dart:developer' as developer;

/// Minimal logger. The app ships no crash- or analytics SDK (NFR-9), so logs stay
/// on the device; this is the one place to swap in something richer.
void logInfo(String message, {String name = 'wuselwall'}) =>
    developer.log(message, name: name);

void logError(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String name = 'wuselwall',
}) => developer.log(
  message,
  name: name,
  level: 1000,
  error: error,
  stackTrace: stackTrace,
);
