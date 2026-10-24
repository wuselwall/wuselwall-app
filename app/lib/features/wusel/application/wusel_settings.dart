import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// How present Wusel is (specs/25 "Settings").
enum WuselPresence {
  /// Animated, and it speaks.
  lively,

  /// Still, small, and only in empty states and on special days.
  quiet,

  /// Not there at all.
  off,
}

/// The settings of a lighter day as they apply to this device and the person at it
/// (specs/21 "A lighter day"). Every `auto` value is resolved here, so the widgets
/// only see what to do.
@immutable
class LighterDay {
  const LighterDay({
    this.wusel = WuselPresence.lively,
    this.outfit = WuselOutfit.none,
    this.sounds = true,
    this.sky = true,
    this.pixelShift = false,
    this.country,
    this.occasionSwitches = const {},
    this.values = const {},
  });

  final WuselPresence wusel;
  final WuselOutfit outfit;

  /// Whether this device makes sounds at all; the acting member's
  /// `member.completion_sound` and the night still apply on top.
  final bool sounds;
  final bool sky;
  final bool pixelShift;

  /// The country of `household.region` (`DE` of `DE-BE`), for the occasions' defaults.
  final String? country;

  /// `ambience.*` as stored: true, false, or 'auto'.
  final Map<String, Object?> occasionSwitches;

  /// Every other effective value of the household, by key.
  final Map<String, Object?> values;

  Object? value(String key) => values[key];
}

/// Resolves `auto` and the precedence of member over device over household.
@visibleForTesting
LighterDay resolveLighterDay({
  required List<SettingEntry> entries,
  required UiRegister register,
  required String? deviceId,
  required Member? acting,
}) {
  Object? read(String key, {String? profileId, String? device}) =>
      resolveSetting(
        entries,
        key,
        profileId: profileId,
        deviceId: device,
      )?.value;

  WuselPresence? presence(Object? v) => switch (v) {
    'lively' => WuselPresence.lively,
    'quiet' => WuselPresence.quiet,
    'off' => WuselPresence.off,
    _ => null,
  };

  // The person's own choice wins while they are at the device (specs/25); `auto` (or a
  // server without the key) is no choice. Then the wall follows its own setting, and
  // a phone or the kid register the default: children lively, adults quiet.
  final memberChoice = acting == null
      ? null
      : presence(read('member.wusel', profileId: acting.id));
  final WuselPresence wusel;
  if (memberChoice != null) {
    wusel = memberChoice;
  } else if (register == UiRegister.kiosk) {
    wusel =
        presence(read('device.wusel', device: deviceId)) ??
        WuselPresence.lively;
  } else {
    final child = acting?.isChild ?? register == UiRegister.kid;
    wusel = child ? WuselPresence.lively : WuselPresence.quiet;
  }

  final outfit = acting == null
      ? WuselOutfit.none
      : WuselOutfit.parse(read('member.wusel_outfit', profileId: acting.id));

  bool autoSwitch(Object? v, {required bool auto}) => switch (v) {
    'on' || true => true,
    'off' || false => false,
    _ => auto,
  };

  final kiosk = register == UiRegister.kiosk;
  final region = read('household.region') as String?;
  return LighterDay(
    wusel: wusel,
    outfit: outfit,
    sounds: autoSwitch(read('device.sounds', device: deviceId), auto: !kiosk),
    sky: read('device.sky', device: deviceId) != false,
    pixelShift: autoSwitch(
      read('device.pixel_shift', device: deviceId),
      auto: kiosk,
    ),
    country: region?.split('-').first.toUpperCase(),
    occasionSwitches: {
      for (final e in entries)
        if (e.key.startsWith('ambience.') &&
            e.profileId == null &&
            e.deviceId == null)
          e.key: e.value,
    },
    values: {
      for (final e in entries)
        if (e.profileId == null && e.deviceId == null) e.key: e.value,
    },
  );
}

/// The resolved settings of a lighter day for this device and whoever is at it. While
/// the settings load (or on a device without a household) everything is at its
/// curated default.
final lighterDayProvider = Provider.autoDispose<LighterDay>((ref) {
  final entries =
      ref.watch(householdSettingsProvider).value ?? const <SettingEntry>[];
  final register = ref.watch(uiRegisterProvider);
  final deviceId = ref.watch(deviceProvider).value?.deviceId;
  final actingId = ref.watch(actingProfileProvider);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final acting = members.where((m) => m.id == actingId).firstOrNull;
  return resolveLighterDay(
    entries: entries,
    register: register,
    deviceId: deviceId,
    acting: acting,
  );
});

/// The family's colours for Wusel's tufts, in board order: active members only.
final wuselTuftsProvider = Provider.autoDispose<List<Color>>((ref) {
  final members = [...?ref.watch(membersProvider).value?.where((m) => m.active)]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [for (final m in members.take(6)) m.color];
});

/// Which tuft belongs to the acting member, so Wusel can turn it to the front.
final wuselFrontTuftProvider = Provider.autoDispose<int?>((ref) {
  final acting = ref.watch(actingProfileProvider);
  if (acting == null) return null;
  final members = [...?ref.watch(membersProvider).value?.where((m) => m.active)]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final i = members.take(6).toList().indexWhere((m) => m.id == acting);
  return i < 0 ? null : i;
});

/// Whether the household's server knows a lighter day: it announces the feature in its
/// discovery document (ADR-020). Against an older server the controls that would write
/// the new fields stay hidden instead of failing (each app release supports the previous
/// server release too).
final lighterDaySupportedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(serverSupportsProvider(featureLighterDay)),
);
