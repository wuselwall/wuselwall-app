import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';

/// The device's languages, in its order of preference; updated when they change while
/// the app runs.
class DeviceLocalesNotifier extends Notifier<List<Locale>>
    with WidgetsBindingObserver {
  @override
  List<Locale> build() {
    final binding = WidgetsBinding.instance..addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.locales;
  }

  @override
  void didChangeLocales(List<Locale>? locales) =>
      state = locales ?? WidgetsBinding.instance.platformDispatcher.locales;
}

final deviceLocalesProvider =
    NotifierProvider<DeviceLocalesNotifier, List<Locale>>(
      DeviceLocalesNotifier.new,
    );

/// The locale this device shows (specs/09 "Regional German"): the person's choice, else
/// the device's language, with German written as the family's country writes it. The
/// app and what is shown outside it, such as the reminders, both read it.
final appLocaleProvider = Provider<Locale>(
  (ref) => effectiveAppLocale(
    chosen: ref.watch(appLanguageProvider).value,
    device: ref.watch(deviceLocalesProvider),
    familyCountry: ref.watch(householdCountryProvider),
  ),
);
