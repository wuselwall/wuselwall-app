import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';

/// The moments Wusel has something to say (specs/25 "Voice"). Each has three to five
/// variants, written per language, never the same twice in a row on one device.
enum WuselMoment {
  helloMorning,
  helloDay,
  helloEvening,
  allDone,
  rewardSent,
  wallMorning,
  wallMemberDone,
}

bool get _underTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

abstract final class WuselLines {
  static final _last = <WuselMoment, int>{};
  static final _random = math.Random();

  /// A variant of [moment] other than the one shown last on this device.
  static String pick(
    AppLocalizations l10n,
    WuselMoment moment, {
    String name = '',
  }) {
    final variants = _variants(l10n, moment, name);
    // Screenshots and tests need the same words every time.
    if (StillMode.enabled || _underTest) return variants.first;
    var i = _random.nextInt(variants.length);
    if (variants.length > 1 && i == _last[moment]) {
      i = (i + 1) % variants.length;
    }
    _last[moment] = i;
    return variants[i];
  }

  /// A variant chosen by [seed], the same on every rebuild and every device: for a
  /// line drawn by a stateless screen, such as the wall's (a member and a date).
  static String stable(
    AppLocalizations l10n,
    WuselMoment moment, {
    required int seed,
    String name = '',
  }) {
    final variants = _variants(l10n, moment, name);
    return variants[seed.abs() % variants.length];
  }

  @visibleForTesting
  static void reset() => _last.clear();

  static List<String> _variants(
    AppLocalizations l10n,
    WuselMoment moment,
    String name,
  ) => switch (moment) {
    WuselMoment.helloMorning => [
      l10n.wuselHelloMorning1(name),
      l10n.wuselHelloMorning2(name),
      l10n.wuselHelloMorning3(name),
    ],
    WuselMoment.helloDay => [
      l10n.wuselHelloDay1(name),
      l10n.wuselHelloDay2(name),
      l10n.wuselHelloDay3(name),
    ],
    WuselMoment.helloEvening => [
      l10n.wuselHelloEvening1(name),
      l10n.wuselHelloEvening2(name),
      l10n.wuselHelloEvening3(name),
    ],
    WuselMoment.allDone => [
      l10n.wuselAllDone1,
      l10n.wuselAllDone2,
      l10n.wuselAllDone3,
      l10n.wuselAllDone4,
    ],
    WuselMoment.rewardSent => [l10n.wuselRewardSent1, l10n.wuselRewardSent2],
    WuselMoment.wallMorning => [
      l10n.wuselWallMorning1,
      l10n.wuselWallMorning2,
      l10n.wuselWallMorning3,
    ],
    WuselMoment.wallMemberDone => [
      l10n.wuselWallMemberDone1(name),
      l10n.wuselWallMemberDone2(name),
    ],
  };

  /// The greeting for the time of day: morning until 11, evening from 17. In still mode
  /// always the daytime one, so a screenshot does not depend on when it was taken.
  static WuselMoment helloAt(DateTime now) => StillMode.enabled
      ? WuselMoment.helloDay
      : now.hour < 11
      ? WuselMoment.helloMorning
      : now.hour < 17
      ? WuselMoment.helloDay
      : WuselMoment.helloEvening;
}
