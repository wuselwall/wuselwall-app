import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/confetti.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/data/kid_birthday_store.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// The child's own birthday, the first open of the kid home that day: confetti over the
/// whole screen behind Wusel in the party hat, and the badge sound (specs/25, specs/26
/// "Celebrations"). Once per day per device; the caller has checked that it is the
/// day, that it is not night and that the household keeps the birthday ambience on.
Future<void> showKidBirthdayOnce(
  BuildContext context,
  WidgetRef ref, {
  required Member member,
  required DateTime today,
}) async {
  final store = ref.read(kidBirthdayStoreProvider);
  if (!await store.claim(member.id, today)) return;
  if (!context.mounted) return;
  final motion = motionAllowed(context);
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: member.displayName,
    transitionDuration: motion ? Tokens.motionStandard : Duration.zero,
    pageBuilder: (_, _, _) => KidBirthdayCelebration(member: member),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class KidBirthdayCelebration extends ConsumerStatefulWidget {
  const KidBirthdayCelebration({required this.member, super.key});

  final Member member;

  /// How long the moment lasts before it closes by itself; a tap closes it sooner.
  static const length = Duration(seconds: 2);

  @override
  ConsumerState<KidBirthdayCelebration> createState() =>
      _KidBirthdayCelebrationState();
}

class _KidBirthdayCelebrationState
    extends ConsumerState<KidBirthdayCelebration> {
  late final Timer _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(KidBirthdayCelebration.length, _close);
    // The sound and the haptic follow the device's, the member's and the night's
    // rules (Celebration.cue).
    unawaited(ref.read(celebrationProvider).cue(Cue.badge));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final ww = context.ww;
    final colors = ww.member(member.color);
    final motion = motionAllowed(context);
    return Material(
      color: colors.tint,
      child: GestureDetector(
        key: const ValueKey('kid-birthday'),
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (motion)
              IgnorePointer(
                child: ConfettiBurst(
                  colors: [
                    for (final c in ref.watch(wuselTuftsProvider))
                      ww.member(c).ink,
                    ww.points,
                  ],
                  duration: KidBirthdayCelebration.length,
                ),
              ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A quiet Wusel comes for the special day too, held still.
                      const FamilyWusel(
                        pose: WuselPose.cheer,
                        size: 200,
                        outfit: WuselOutfit.party,
                        quietAllowed: true,
                      ),
                      const SizedBox(height: Tokens.space4),
                      Text(
                        context.l10n.wuselBirthdayCheer(member.displayName),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
