import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/member_circle.dart';

/// "Wer bist du?" on a shared kid device: one big avatar per member. Tapping one makes
/// that person the acting profile, and the screen behind it appears.
class KidPicker extends ConsumerWidget {
  const KidPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider);
    return Padding(
      key: const ValueKey('kid-picker'),
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        children: [
          const SizedBox(height: Tokens.space6),
          Text(
            l10n.kidWhoAreYou,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Tokens.space8),
          Expanded(
            child: AsyncValueView<List<Member>>(
              value: members,
              onRetry: () => ref.invalidate(membersProvider),
              data: (list) {
                final active = list.where((m) => m.active).toList();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final grid = pickerGrid(
                      count: active.length,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      label: _Choice.labelHeight(context),
                    );
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var r = 0;
                                r < active.length;
                                r += grid.columns
                              )
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: r == 0 ? 0 : pickerGap,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var i = r;
                                        i < r + grid.columns &&
                                            i < active.length;
                                        i++
                                      )
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: i == r ? 0 : Tokens.space1,
                                          ),
                                          child: _Choice(
                                            member: active[i],
                                            size: grid.size,
                                            onTap: () => ref
                                                .read(
                                                  actingProfileProvider
                                                      .notifier,
                                                )
                                                .select(active[i].id),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The space between two choices, across and down.
const pickerGap = Tokens.space6;

/// How the picker lays out [count] people in a [width] × [height] area: the
/// largest circles that fit, in rows as even as possible (four people are 2 × 2 or
/// 4 × 1, never 3 + 1), between 72 and 200 dp. [label] is the height of a name
/// under its circle. When even the smallest circles do not fit, the area scrolls.
@visibleForTesting
({int columns, double size}) pickerGrid({
  required int count,
  required double width,
  required double height,
  required double label,
}) {
  if (count == 0) return (columns: 1, size: 132);
  var best = (columns: math.min(count, 2), size: 72.0);
  var bestSize = 0.0;
  for (var rows = 1; rows <= count; rows++) {
    final columns = (count / rows).ceil();
    // Each choice is its circle plus room for the name beside it (see _Choice).
    final across =
        (width - (columns - 1) * Tokens.space1) / columns -
        (pickerGap - Tokens.space1);
    final down = (height - (rows - 1) * pickerGap) / rows - label;
    final size = math.min(math.min(across, down), 200.0);
    if (size > bestSize) {
      bestSize = size;
      best = (columns: columns, size: size);
    }
  }
  if (bestSize < 72) {
    // Too many for the screen: two across, scrolling.
    final across = (width - Tokens.space1) / 2 - (pickerGap - Tokens.space1);
    return (columns: 2, size: math.max(72.0, math.min(across, 200.0)));
  }
  return best;
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.member,
    required this.size,
    required this.onTap,
  });

  final Member member;
  final double size;
  final VoidCallback onTap;

  /// The name under a circle and the gap above it.
  static double labelHeight(BuildContext context) =>
      Tokens.space2 +
      MediaQuery.textScalerOf(
        context,
      ).scale((Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) * 1.3);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      focusable: true,
      onTap: onTap,
      label: member.displayName,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('kid-pick-${member.id}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberCircle(member: member, size: size),
            const SizedBox(height: Tokens.space2),
            SizedBox(
              // The name may use the gap beside its circle ("Thomas" under a
              // small circle on a phone).
              width: size + pickerGap - Tokens.space1,
              child: Text(
                member.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
