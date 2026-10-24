import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';

/// Wusel in the wall's header (specs/25 "Where Wusel appears", kiosk): it waves for the
/// first half hour of the morning, wears the party hat on a birthday and cheers once
/// on the hour, thinks while the board is offline, and sleeps at night. In between it
/// sits still in its corner: nothing moves at two metres but a moment.
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
    final morning = !night && now.hour == 6 && now.minute < 30;
    final style = boardUi(24, weight: FontWeight.w700);

    if (night) {
      return const FamilyWusel(pose: WuselPose.sleep, size: size);
    }
    if (stale) {
      return const FamilyWusel(pose: WuselPose.think, size: size);
    }
    if (birthday) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: WuselSays(
          line: ref.watch(birthdayLineProvider) ?? '',
          pose: WuselPose.cheer,
          size: size,
          // Once on each hour: the wall's quietest loud moment.
          moment: now.hour,
          outfit: WuselOutfit.party,
          quietAllowed: true,
          style: style,
        ),
      );
    }
    if (morning) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: WuselSays(
          line: WuselLines.stable(l10n, WuselMoment.wallMorning, seed: now.day),
          pose: WuselPose.wave,
          size: size,
          style: style,
        ),
      );
    }
    return const FamilyWusel(size: size);
  }
}

/// "Olivia hat Geburtstag!" for today's birthdays; null when there are none.
final birthdayLineProvider = Provider.autoDispose<String?>((ref) => null);
