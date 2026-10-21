import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';

/// How much of Einstellungen this device shows. Purely visual: a hidden setting keeps its
/// value and stays in effect. Per device, like the appearance; [basic] is the default so a
/// new family is not met with every option at once.
enum SettingsView { basic, advanced }

abstract class SettingsViewStore {
  Future<SettingsView> read();

  Future<void> write(SettingsView view);
}

class SecureSettingsViewStore implements SettingsViewStore {
  SecureSettingsViewStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.settings.view';

  final FlutterSecureStorage _storage;

  @override
  Future<SettingsView> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return SettingsView.values.where((v) => v.name == raw).firstOrNull ??
          SettingsView.basic;
    } on Object catch (error, stack) {
      logError(
        'Reading the settings view failed',
        error: error,
        stackTrace: stack,
      );
      return SettingsView.basic;
    }
  }

  @override
  Future<void> write(SettingsView view) async {
    try {
      await _storage.write(key: _key, value: view.name);
    } on Object catch (error, stack) {
      logError(
        'Saving the settings view failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

/// The choice in memory: the demo, and tests (secure storage has no platform there).
class MemorySettingsViewStore implements SettingsViewStore {
  MemorySettingsViewStore([this.view = SettingsView.basic]);

  SettingsView view;

  @override
  Future<SettingsView> read() async => view;

  @override
  Future<void> write(SettingsView view) async => this.view = view;
}

final settingsViewStoreProvider = Provider<SettingsViewStore>(
  (ref) => SecureSettingsViewStore(),
);

class SettingsViewNotifier extends AsyncNotifier<SettingsView> {
  @override
  Future<SettingsView> build() => ref.watch(settingsViewStoreProvider).read();

  /// Applies [view] at once and keeps it for the next start.
  Future<void> select(SettingsView view) async {
    state = AsyncData(view);
    await ref.read(settingsViewStoreProvider).write(view);
  }
}

final settingsViewProvider =
    AsyncNotifierProvider<SettingsViewNotifier, SettingsView>(
      SettingsViewNotifier.new,
    );

/// Whether this device shows the advanced settings. Basic until the choice is read.
final showAdvancedSettingsProvider = Provider<bool>(
  (ref) => ref.watch(settingsViewProvider).value == SettingsView.advanced,
);
