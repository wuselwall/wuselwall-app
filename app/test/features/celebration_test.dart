import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

class _Night extends NightNotifier {
  _Night(this.night);

  final bool night;

  @override
  bool build() => night;
}

class _Nobody extends ActingProfileNotifier {
  @override
  String? build() => null;
}

class _Recorder implements SoundPlayer {
  final played = <Cue>[];

  @override
  Future<void> play(Cue cue) async => played.add(cue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> haptics;
  late _Recorder sounds;

  setUp(() {
    haptics = [];
    sounds = _Recorder();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Celebration celebration(UiRegister register, {bool night = false}) {
    final container = ProviderContainer(
      overrides: [
        uiRegisterProvider.overrideWithValue(register),
        nightProvider.overrideWith(() => _Night(night)),
        actingProfileProvider.overrideWith(_Nobody.new),
        lighterDayProvider.overrideWith((ref) => const LighterDay()),
        householdSettingsProvider.overrideWith(
          (ref) async => const <SettingEntry>[],
        ),
        soundPlayerProvider.overrideWithValue(sounds),
      ],
    );
    addTearDown(container.dispose);
    return container.read(celebrationProvider);
  }

  group('haptics and sound follow the register and the night (specs/26)', () {
    test('kid: a light tap and the sound on a tick', () async {
      await celebration(UiRegister.kid).cue(Cue.tick);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(sounds.played, [Cue.tick]);
    });

    test('kid: a medium tap on the last chore', () async {
      await celebration(UiRegister.kid).cue(Cue.fertig);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(sounds.played, [Cue.fertig]);
    });

    test('adult: neither haptic nor sound', () async {
      await celebration(UiRegister.adult).cue(Cue.fertig);
      expect(haptics, isEmpty);
      expect(sounds.played, isEmpty);
    });

    test('at night: neither haptic nor sound', () async {
      await celebration(UiRegister.kid, night: true).cue(Cue.tick);
      expect(haptics, isEmpty);
      expect(sounds.played, isEmpty);
    });
  });

  group('one celebration per moment', () {
    test('a moment celebrates once', () {
      final c = celebration(UiRegister.kiosk);
      final t = DateTime(2026, 10, 24, 18);
      final key = Celebration.lastChoreOf('p1', now: t);
      expect(c.claimMoment(key, now: t), isTrue);
      expect(
        c.claimMoment(key, now: t.add(const Duration(minutes: 5))),
        isFalse,
      );
    });

    test('no second burst while one runs; the next one after it', () {
      final c = celebration(UiRegister.kiosk);
      final t = DateTime(2026, 10, 24, 18);
      expect(c.claimMoment('a', now: t), isTrue);
      expect(
        c.claimMoment('b', now: t.add(const Duration(milliseconds: 600))),
        isFalse,
      );
      expect(c.claimMoment('b', now: t.add(Celebration.burst)), isTrue);
    });

    test('each person and each day is its own moment', () {
      final t = DateTime(2026, 10, 24, 18);
      expect(
        Celebration.lastChoreOf('p1', now: t),
        isNot(Celebration.lastChoreOf('p2', now: t)),
      );
      expect(
        Celebration.lastChoreOf('p1', now: t),
        isNot(
          Celebration.lastChoreOf('p1', now: t.add(const Duration(days: 1))),
        ),
      );
    });
  });

  test(
    'the sounds respect the silent switch and leave other audio playing',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final ios = celebrationAudioContext.iOS;
      expect(ios.category, AVAudioSessionCategory.ambient);
      final android = celebrationAudioContext.android;
      expect(android.audioFocus, AndroidAudioFocus.none);
      expect(android.usageType, isNot(AndroidUsageType.media));
    },
  );
}
