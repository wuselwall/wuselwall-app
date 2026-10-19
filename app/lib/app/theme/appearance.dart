import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';

/// Whether this device shows the light or the dark theme, or follows the OS (the
/// default). Per device, like the OS setting it replaces: a family's phones need not
/// agree. The kiosk's night shade (`nightProvider`) still wins from 21:00 to 06:00.
abstract class AppearanceStore {
  Future<ThemeMode> read();

  Future<void> write(ThemeMode mode);
}

class SecureAppearanceStore implements AppearanceStore {
  SecureAppearanceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.appearance.theme_mode';

  final FlutterSecureStorage _storage;

  @override
  Future<ThemeMode> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return ThemeMode.values.where((m) => m.name == raw).firstOrNull ??
          ThemeMode.system;
    } on Object catch (error, stack) {
      logError(
        'Reading the appearance failed',
        error: error,
        stackTrace: stack,
      );
      return ThemeMode.system;
    }
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } on Object catch (error, stack) {
      logError('Saving the appearance failed', error: error, stackTrace: stack);
    }
  }
}

/// The appearance in memory: the demo, and tests (secure storage has no platform there).
class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.mode = ThemeMode.system]);

  ThemeMode mode;

  @override
  Future<ThemeMode> read() async => mode;

  @override
  Future<void> write(ThemeMode mode) async => this.mode = mode;
}

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => SecureAppearanceStore(),
);

class AppearanceNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() => ref.watch(appearanceStoreProvider).read();

  /// Applies [mode] at once and keeps it for the next start.
  Future<void> select(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(appearanceStoreProvider).write(mode);
  }
}

final appearanceProvider = AsyncNotifierProvider<AppearanceNotifier, ThemeMode>(
  AppearanceNotifier.new,
);
