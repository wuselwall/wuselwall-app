import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The four sounds of specs/26, synthesised by `scripts/sound-effects.mjs`.
enum Cue {
  /// A chore ticked.
  tick,

  /// Points arriving in the balance.
  coin,

  /// The last chore of the day.
  fertig,

  /// A badge earned or a reward redeemed.
  badge;

  String get asset => 'sounds/$name.wav';

  /// The haptic that goes with the cue; phones and tablets without a motor ignore it.
  Future<void> haptic() => switch (this) {
    tick || coin => HapticFeedback.lightImpact(),
    fertig || badge => HapticFeedback.mediumImpact(),
  };
}

/// Plays a bundled sound. Replaced in tests, where there is no audio plugin.
abstract interface class SoundPlayer {
  Future<void> play(Cue cue);
}

/// How the sounds share the device's audio (specs/26 "Sound and haptics"): on iOS the
/// ambient session, which the silent switch and the ring/silent setting mute and which
/// mixes with whatever else plays; on Android a short sonification on the
/// notification stream (silent in silent mode) that asks for no audio focus, so the
/// family's music keeps playing.
final celebrationAudioContext = AudioContext(
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  android: const AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.notificationEvent,
    audioFocus: AndroidAudioFocus.none,
  ),
);

/// A low-latency player per cue, created when first needed: a tick that arrives
/// 300 ms late feels broken (specs/26).
class AudioplayersSoundPlayer implements SoundPlayer {
  final _players = <Cue, AudioPlayer>{};

  /// Set once, before the first player exists: on Android new players copy the
  /// global context, on iOS it is the app's audio session.
  Future<void>? _context;

  @override
  Future<void> play(Cue cue) async {
    try {
      await (_context ??= AudioPlayer.global.setAudioContext(
        celebrationAudioContext,
      ));
      var player = _players[cue];
      if (player == null) {
        player = _players[cue] = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await player.stop();
      await player.play(AssetSource(cue.asset));
    } on Object catch (e) {
      // A missing sound is never worth an error on a child's screen.
      logInfo('sound ${cue.name} not played: $e');
    }
  }
}

class _SilentSoundPlayer implements SoundPlayer {
  const _SilentSoundPlayer();

  @override
  Future<void> play(Cue cue) async {}
}

/// Under `flutter test` there is no audio plugin, and creating a player would leave
/// failing platform calls behind.
bool get _underTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

final soundPlayerProvider = Provider<SoundPlayer>(
  (ref) => _underTest ? const _SilentSoundPlayer() : AudioplayersSoundPlayer(),
);

/// Plays a cue's sound and haptic when the rules allow (specs/26 "Sound and haptics"):
/// the device's `device.sounds`, the acting member's `member.completion_sound`, never at
/// night, and nothing in the adult register (its one haptic, the end of a shopping
/// trip, is [shoppingTrip], not a cue). The haptic follows the register and the night
/// only.
class Celebration {
  Celebration(this._ref);

  final Ref _ref;

  /// The moments already celebrated, and when the running burst ends.
  final _celebrated = <String>{};
  DateTime? _burstUntil;

  /// How long a burst counts as running: the confetti's 1.4 s.
  static const burst = Duration(milliseconds: 1400);

  Future<void> cue(Cue cue) async {
    if (_quiet()) return;
    unawaited(cue.haptic());
    if (!_soundAllowed()) return;
    await _ref.read(soundPlayerProvider).play(cue);
  }

  /// Whether the moment [key] (say, one person's last chore of one day) may celebrate:
  /// once per moment, and not while another burst still runs (specs/26 "The budget is
  /// one celebration per moment"). A true answer claims it.
  bool claimMoment(String key, {DateTime? now}) {
    final at = now ?? DateTime.now();
    if (_burstUntil case final until? when at.isBefore(until)) return false;
    if (!_celebrated.add(key)) return false;
    _burstUntil = at.add(burst);
    return true;
  }

  /// The moment of [profileId]'s last chore today.
  static String lastChoreOf(String profileId, {DateTime? now}) {
    final d = now ?? DateTime.now();
    return 'last-chore/$profileId/${d.year}-${d.month}-${d.day}';
  }

  /// The moment of the shopping trip on [listId] that bought [itemIds]: ticking the
  /// last item and then finishing the trip is one moment, so it celebrates once. Items
  /// added and bought afterwards make a new trip.
  static String tripOf(String listId, Iterable<String> itemIds) =>
      'shopping-trip/$listId/${(itemIds.toList()..sort()).join(',')}';

  /// The end of a shopping trip (specs/26 "Celebrations"): the adult register's one
  /// haptic, a light one, and never a sound, because the phone is in a shop. Nothing
  /// at night or on a device that `device.sounds` keeps quiet.
  Future<void> shoppingTrip() async {
    if (_ref.read(nightProvider) || !_ref.read(lighterDayProvider).sounds) {
      return;
    }
    await HapticFeedback.lightImpact();
  }

  /// No haptic and no sound: the adult register and the night.
  bool _quiet() =>
      _ref.read(uiRegisterProvider) == UiRegister.adult ||
      _ref.read(nightProvider);

  bool _soundAllowed() {
    if (!_ref.read(lighterDayProvider).sounds) return false;
    final acting = _ref.read(actingProfileProvider);
    if (acting == null) return true;
    final entries = _ref.read(householdSettingsProvider).value ?? const [];
    final own = resolveSetting(
      entries,
      'member.completion_sound',
      profileId: acting,
    )?.value;
    return own != false;
  }
}

final celebrationProvider = Provider<Celebration>(Celebration.new);
