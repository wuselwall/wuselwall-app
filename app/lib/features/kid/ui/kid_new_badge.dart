import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// A badge the child earned in the last two days: Wusel holds up the star and names it
/// (specs/25, pose `proud`). The card grows in from the centre on the bouncy spring
/// (specs/26). The badge sound plays once per badge while the app runs, not on every
/// visit.
///
/// Where the screen already has its Wusel ([withWusel] false: *Mein Tag*, whose
/// greeting Wusel holds up the star), the card shows a gold star beside the line, so
/// there is one Wusel per screen (specs/25).
class KidNewBadge extends ConsumerStatefulWidget {
  const KidNewBadge({required this.actor, this.withWusel = true, super.key});

  final String actor;
  final bool withWusel;

  /// The badges celebrated with a sound since the app started.
  static final _sounded = <String>{};

  @override
  ConsumerState<KidNewBadge> createState() => _KidNewBadgeState();
}

class _KidNewBadgeState extends ConsumerState<KidNewBadge> {
  @override
  Widget build(BuildContext context) {
    final badge = ref.watch(kidNewBadgeProvider(widget.actor));
    if (badge == null) return const SizedBox.shrink();
    final key = '${widget.actor}/${badge.id}';
    if (KidNewBadge._sounded.add(key)) {
      // After the frame: the sound belongs to the moment the card appears.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(celebrationProvider).cue(Cue.badge));
      });
    }
    final line = context.l10n.wuselBadge(badge.title);
    final style = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space3),
      child: KidGrowIn(
        // A new badge grows in again.
        key: ValueKey(badge.id),
        child: KidCard(
          child: widget.withWusel
              ? WuselSays(
                  line: line,
                  pose: WuselPose.proud,
                  size: 96,
                  moment: badge.id,
                  tappable: true,
                  style: style,
                )
              : Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.star_rounded,
                        size: 56,
                        color: context.ww.points,
                      ),
                    ),
                    const SizedBox(width: Tokens.space3),
                    Expanded(child: Text(line, style: style)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Grows [child] in from its centre on [Tokens.springBouncy] when it first appears,
/// overshooting a little (specs/26 "Celebrations"). Under reduced motion it is there
/// at once.
class KidGrowIn extends StatefulWidget {
  const KidGrowIn({required this.child, super.key});

  final Widget child;

  @override
  State<KidGrowIn> createState() => _KidGrowInState();
}

class _KidGrowInState extends State<KidGrowIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!motionAllowed(context)) {
      _scale.value = 1;
      return;
    }
    unawaited(
      _scale.animateWith(SpringSimulation(Tokens.springBouncy, 0, 1, 0)),
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Plays the badge sound once when a reward the child asked for is approved on another
/// device and arrives here with the realtime refresh (specs/26: the badge sound is for
/// a reward redeemed). [onApproved] lets the screen show it too. Call from `build`.
void kidListenForApprovals(
  WidgetRef ref,
  String actor, {
  VoidCallback? onApproved,
}) {
  ref.listen<AsyncValue<List<RewardRedemption>>>(redemptionsProvider, (
    previous,
    next,
  ) {
    final before = previous?.value;
    final after = next.value;
    if (before == null || after == null) return;
    final approved = kidNewlyApproved(before, after, actor);
    if (approved.isEmpty) return;
    final celebration = ref.read(celebrationProvider);
    // One celebration per moment: the same yes never sounds twice, and two yeses at
    // once sound as one.
    final fresh = [
      for (final id in approved)
        if (celebration.claimMoment('reward-approved/$id')) id,
    ];
    if (fresh.isEmpty) return;
    unawaited(celebration.cue(Cue.badge));
    onApproved?.call();
  });
}
