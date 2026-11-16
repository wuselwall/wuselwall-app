import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/logging/log.dart';

/// Whether this device shows the light or the dark theme, or follows the OS (the
/// default). Per device, like the OS setting it replaces: a family's phones need not
/// agree. The kiosk's night shade (`nightProvider`) still wins during its night hours.
///
/// It also keeps the device's colour themes ([Looks]): one for light and one for dark.
abstract class AppearanceStore {
  Future<ThemeMode> read();

  Future<void> write(ThemeMode mode);

  Future<Looks> readLooks();

  Future<void> writeLooks(Looks looks);
}

/// The colour themes this device shows (specs/17 "Themes"): one for light, one for dark.
/// Which of the two is on screen is the appearance's business ([ThemeMode]).
@immutable
class Looks {
  const Looks({
    this.light = Look.frisch,
    this.dark = Look.blaueStunde,
    this.asked = false,
  });

  final Look light;
  final Look dark;

  /// Whether this device has offered the choice: the sheet on its first arrival at
  /// home was closed, or someone chose a theme in the settings. It is offered once.
  final bool asked;

  Look of(Shade shade) => switch (shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => Look.night,
  };

  /// These themes with [look] as the choice for its shade.
  Looks choosing(Look look) => switch (look.shade) {
    Shade.light => Looks(light: look, dark: dark, asked: true),
    Shade.dark => Looks(light: light, dark: look, asked: true),
    Shade.night => this,
  };

  Looks get answered => Looks(light: light, dark: dark, asked: true);

  @override
  bool operator ==(Object other) =>
      other is Looks &&
      other.light == light &&
      other.dark == dark &&
      other.asked == asked;

  @override
  int get hashCode => Object.hash(light, dark, asked);
}

class SecureAppearanceStore implements AppearanceStore {
  SecureAppearanceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.appearance.theme_mode';
  static const _lightKey = 'wuselwall.appearance.look_light';
  static const _darkKey = 'wuselwall.appearance.look_dark';
  static const _askedKey = 'wuselwall.appearance.look_asked';

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

  @override
  Future<Looks> readLooks() async {
    try {
      final light = await _storage.read(key: _lightKey);
      final dark = await _storage.read(key: _darkKey);
      final asked = await _storage.read(key: _askedKey);
      return Looks(
        light: Look.named(light, Shade.light) ?? Look.frisch,
        dark: Look.named(dark, Shade.dark) ?? Look.blaueStunde,
        asked: asked != null,
      );
    } on Object catch (error, stack) {
      logError('Reading the themes failed', error: error, stackTrace: stack);
      // A device whose storage cannot be read could not keep the answer either:
      // it is not asked on every start.
      return const Looks(asked: true);
    }
  }

  @override
  Future<void> writeLooks(Looks looks) async {
    try {
      await _storage.write(key: _lightKey, value: looks.light.name);
      await _storage.write(key: _darkKey, value: looks.dark.name);
      if (looks.asked) await _storage.write(key: _askedKey, value: '1');
    } on Object catch (error, stack) {
      logError('Saving the themes failed', error: error, stackTrace: stack);
    }
  }
}

/// The appearance in memory: the demo, and tests (secure storage has no platform there).
class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([
    this.mode = ThemeMode.system,
    this.looks = const Looks(asked: true),
  ]);

  ThemeMode mode;

  /// Already asked unless a test or a demo scenario is about the first arrival.
  Looks looks;

  @override
  Future<ThemeMode> read() async => mode;

  @override
  Future<void> write(ThemeMode mode) async => this.mode = mode;

  @override
  Future<Looks> readLooks() async => looks;

  @override
  Future<void> writeLooks(Looks looks) async => this.looks = looks;
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

class LooksNotifier extends AsyncNotifier<Looks> {
  @override
  Future<Looks> build() => ref.watch(appearanceStoreProvider).readLooks();

  /// Shows [look] at once and keeps it for the next start.
  Future<void> choose(Look look) =>
      _set((state.value ?? const Looks()).choosing(look));

  /// The choice was offered; it is not offered again.
  Future<void> markAsked() => _set((state.value ?? const Looks()).answered);

  Future<void> _set(Looks looks) async {
    if (state.value == looks) return;
    state = AsyncData(looks);
    await ref.read(appearanceStoreProvider).writeLooks(looks);
  }
}

/// The colour themes of this device, per device like [appearanceProvider].
final looksProvider = AsyncNotifierProvider<LooksNotifier, Looks>(
  LooksNotifier.new,
);
