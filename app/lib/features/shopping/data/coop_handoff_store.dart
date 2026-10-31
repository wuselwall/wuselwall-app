import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';

/// This device's link to the Coop list (specs/30, decision 1): the list id and the
/// entries the pushes made. On the device only; the server never sees it. The Coop
/// session itself lives in the WebView's cookies, not here. Null: not connected.
abstract class CoopHandoffStore {
  Future<HandoffState?> read();

  Future<void> write(HandoffState state);

  Future<void> clear();
}

class SecureCoopHandoffStore implements CoopHandoffStore {
  SecureCoopHandoffStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.shopping.coop';

  final FlutterSecureStorage _storage;

  @override
  Future<HandoffState?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return HandoffState.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object catch (error, stack) {
      logError(
        'Reading the Coop list link failed',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  @override
  Future<void> write(HandoffState state) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(state.toJson()));
    } on Object catch (error, stack) {
      logError(
        'Saving the Coop list link failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (error, stack) {
      logError(
        'Removing the Coop list link failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

/// The link in memory: the demo, and tests (secure storage has no platform there).
class MemoryCoopHandoffStore implements CoopHandoffStore {
  MemoryCoopHandoffStore([this.state]);

  HandoffState? state;

  @override
  Future<HandoffState?> read() async => state;

  @override
  Future<void> write(HandoffState state) async => this.state = state;

  @override
  Future<void> clear() async => state = null;
}

final coopHandoffStoreProvider = Provider<CoopHandoffStore>(
  (ref) => SecureCoopHandoffStore(),
);
