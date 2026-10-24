import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// A badge the child earned in the last two days: Wusel holds up the star and names it
/// (specs/25, pose `proud`). The badge sound plays once per badge while the app runs,
/// not on every visit.
class KidNewBadge extends ConsumerStatefulWidget {
  const KidNewBadge({required this.actor, super.key});

  final String actor;

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
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space3),
      child: KidCard(
        child: WuselSays(
          line: context.l10n.wuselBadge(badge.title),
          pose: WuselPose.proud,
          size: 96,
          moment: badge.id,
          tappable: true,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
