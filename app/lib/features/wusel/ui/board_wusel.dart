import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/application/today_tradition_provider.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';

/// The countdown Wusel waves for on [today]: the nearest one, when it is tomorrow or
/// today. The countdowns come nearest first.
Countdown? waveFor(List<Countdown> countdowns, DateTime today) =>
    switch (countdowns.firstOrNull) {
      final c? when c.daysFrom(today) <= 1 => c,
      _ => null,
    };

/// Wusel in the wall's header (specs/25 "Where Wusel appears", kiosk): it waves for the
/// first half hour of the morning, wears the party hat on a birthday and cheers once
/// on the hour, thinks while the board is offline, and sleeps at night. Its morning
/// line names today's tradition, and it waves when a countdown says "Morgen!" or
/// "Heute!". In between it sits still in its corner: nothing moves at two metres but
/// a moment. The corner is Wusel's home on the wall: a tap gives a tickle and the eyes
/// follow the finger for a few seconds, and only a member's last chore takes Wusel
/// out of it (specs/25 "Wusel on the move").
class BoardWusel extends ConsumerWidget {
  const BoardWusel({required this.stale, super.key});

  /// The board shows its last good state: Wusel thinks beside the freshness note.
  final bool stale;

  static const size = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(nowProvider);
    final night = ref.watch(nightProvider);
    final ambience = ref.watch(ambienceProvider);
    final birthday = ambience.birthdays.isNotEmpty;
    final morning =
        !night && isMorningWaveAt(now, ref.watch(nightHoursProvider));
    final style = boardUi(24, weight: FontWeight.w700);

    if (night) {
      return const FamilyWusel(pose: WuselPose.sleep, size: size, home: true);
    }
    if (stale) {
      return const FamilyWusel(pose: WuselPose.think, size: size, home: true);
    }
    if (birthday) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: WuselSays(
          line: l10n.wuselFactBirthday(
            ref
                .watch(birthdaysTodayMembersProvider)
                .map((m) => m.displayName)
                .join(' & '),
          ),
          pose: WuselPose.cheer,
          size: size,
          // Once on each hour: the wall's quietest loud moment.
          moment: now.hour,
          outfit: WuselOutfit.party,
          quietAllowed: true,
          style: style,
          home: true,
          tappable: true,
        ),
      );
    }
    if (morning) {
      // On a tradition's day the morning names it (specs/27 "Familientraditionen").
      final tradition = ref.watch(todayTraditionProvider);
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: WuselSays(
          line: tradition != null
              ? WuselLines.stable(
                  l10n,
                  WuselMoment.wallTradition,
                  seed: now.day,
                  name: tradition,
                )
              : WuselLines.stable(l10n, WuselMoment.wallMorning, seed: now.day),
          pose: WuselPose.wave,
          size: size,
          style: style,
          home: true,
          tappable: true,
        ),
      );
    }
    // A countdown at "Morgen!" or "Heute!" in the footer: this corner Wusel waves for
    // it, the screen's one Wusel (specs/27 "Vorfreude", specs/25), and the footer
    // keeps the words.
    if (waveFor(ref.watch(countdownsProvider), ref.watch(ritualTodayProvider))
        case final soon?) {
      return FamilyWusel(
        pose: WuselPose.wave,
        size: size,
        moment: (soon.kind, soon.date, soon.title),
        home: true,
        tappable: true,
      );
    }
    return const FamilyWusel(size: size, home: true, tappable: true);
  }
}
