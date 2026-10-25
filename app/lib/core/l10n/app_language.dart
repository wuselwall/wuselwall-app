import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/core/logging/log.dart';

/// The language this installation shows, or null: the device's language, with German for
/// any the app does not ship (specs/09). A German variant ("de-CH") may be chosen too. Per device, like the appearance: a family's
/// phones need not agree, and the choice never reaches the server. On the web it lives in
/// the browser's storage of this origin.
abstract class AppLanguageStore {
  Future<Locale?> read();

  Future<void> write(Locale? locale);
}

class SecureAppLanguageStore implements AppLanguageStore {
  SecureAppLanguageStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.language';

  final FlutterSecureStorage _storage;

  @override
  Future<Locale?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      // A tag ("de-CH") since regional German; a plain language code before.
      return [
        ...languageChoices,
        ...supportedLocales,
      ].where((l) => l.toLanguageTag() == raw).firstOrNull;
    } on Object catch (error, stack) {
      logError('Reading the language failed', error: error, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<void> write(Locale? locale) async {
    try {
      if (locale == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: locale.toLanguageTag());
      }
    } on Object catch (error, stack) {
      logError('Saving the language failed', error: error, stackTrace: stack);
    }
  }
}

/// The language in memory: the demo, and tests (secure storage has no platform there).
class MemoryAppLanguageStore implements AppLanguageStore {
  MemoryAppLanguageStore([this.locale]);

  Locale? locale;

  @override
  Future<Locale?> read() async => locale;

  @override
  Future<void> write(Locale? locale) async => this.locale = locale;
}

final appLanguageStoreProvider = Provider<AppLanguageStore>(
  (ref) => SecureAppLanguageStore(),
);

class AppLanguageNotifier extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() => ref.watch(appLanguageStoreProvider).read();

  /// Applies [locale] at once and keeps it for the next start; null follows the device
  /// again.
  Future<void> select(Locale? locale) async {
    state = AsyncData(locale);
    await ref.read(appLanguageStoreProvider).write(locale);
  }
}

/// The chosen language of this installation; null while unknown or when the device's
/// language applies. `MaterialApp.locale` takes it as is.
final appLanguageProvider = AsyncNotifierProvider<AppLanguageNotifier, Locale?>(
  AppLanguageNotifier.new,
);
