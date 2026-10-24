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

/// A low-latency player per cue, created when first needed: a tick that arrives
/// 300 ms late feels broken (specs/26).
class AudioplayersSoundPlayer implements SoundPlayer {
  final _players = <Cue, AudioPlayer>{};

  @override
  Future<void> play(Cue cue) async {
    try {
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
/// night, and never in the adult register except as a haptic.
class Celebration {
  Celebration(this._ref);

  final Ref _ref;

  Future<void> cue(Cue cue) async {
    unawaited(cue.haptic());
    if (!_soundAllowed()) return;
    await _ref.read(soundPlayerProvider).play(cue);
  }

  bool _soundAllowed() {
    if (_ref.read(uiRegisterProvider) == UiRegister.adult) return false;
    if (_ref.read(nightProvider)) return false;
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
