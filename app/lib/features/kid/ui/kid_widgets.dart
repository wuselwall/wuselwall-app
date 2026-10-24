import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';

/// Large, friendly surfaces of the kid register: radius 18, a 2 px hairline, and a
/// minimum height that is a touch target on its own.
class KidCard extends StatelessWidget {
  const KidCard({
    required this.child,
    this.onTap,
    this.color,
    this.highlight = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  /// A hairline in the primary colour: today, or the card the child is on.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRegister.kid.radius),
        side: BorderSide(
          color: highlight ? scheme.primary : context.ww.line,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: child,
        ),
      ),
    );
  }
}

/// A section heading in the kid register's type scale.
class KidSectionTitle extends StatelessWidget {
  const KidSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Tokens.space6, bottom: Tokens.space2),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

/// Reduced motion (specs/17): nothing flies, counts or pulses.
bool kidReduceMotion(BuildContext context) => !motionAllowed(context);

/// The points balance, gold. When it changes it counts to the new value over 600 ms
/// (`easeOutCubic`) and gives a small coin tick; under reduced motion it jumps.
class KidBalancePill extends StatefulWidget {
  const KidBalancePill({required this.balance, super.key});

  final int balance;

  @override
  State<KidBalancePill> createState() => _KidBalancePillState();
}

class _KidBalancePillState extends State<KidBalancePill>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  late int _from = widget.balance;
  late int _to = widget.balance;

  double get _eased => Curves.easeOutCubic.transform(_controller.value);

  int get _shown => (_from + (_to - _from) * _eased).round();

  @override
  void didUpdateWidget(KidBalancePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance == widget.balance) return;
    _from = _shown;
    _to = widget.balance;
    if (kidReduceMotion(context)) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final rising = _to > _from;
    return Semantics(
      label: context.l10n.tasksPointsCount(widget.balance),
      container: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // The coin tick: a small swell as the count lands, only when it went up.
          final tick = rising && _controller.isAnimating
              ? 1 + 0.12 * math.sin(math.pi * _controller.value)
              : 1.0;
          return ExcludeSemantics(
            child: Transform.scale(
              scale: tick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space4,
                  vertical: Tokens.space2,
                ),
                decoration: BoxDecoration(
                  color: ww.points,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: ww.onPoints, size: 28),
                    const SizedBox(width: Tokens.space2),
                    Text(
                      '$_shown',
                      style: TextStyle(
                        fontFamily: Tokens.fontNumeric,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ww.onPoints,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A coin that flies from [from] to [to] over 600 ms, `easeOutCubic`, then goes. Shown
/// in the app's overlay, so it survives the card that launched it. Does nothing when
/// either anchor is not on screen.
void kidFlyCoin(
  BuildContext context, {
  required GlobalKey from,
  required GlobalKey to,
  required int points,
}) {
  final overlay = Overlay.maybeOf(context);
  final start = _centreOf(from);
  final end = _centreOf(to);
  if (overlay == null || start == null || end == null) return;
  final ww = context.ww;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingCoin(
      start: start,
      end: end,
      points: points,
      colour: ww.points,
      onColour: ww.onPoints,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

Offset? _centreOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}

class _FlyingCoin extends StatefulWidget {
  const _FlyingCoin({
    required this.start,
    required this.end,
    required this.points,
    required this.colour,
    required this.onColour,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final int points;
  final Color colour;
  final Color onColour;
  final VoidCallback onDone;

  @override
  State<_FlyingCoin> createState() => _FlyingCoinState();
}

class _FlyingCoinState extends State<_FlyingCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    unawaited(
      _controller.forward().whenComplete(() {
        if (mounted) widget.onDone();
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final at = Offset.lerp(
        widget.start,
        widget.end,
        Curves.easeOutCubic.transform(_controller.value),
      )!;
      return Positioned(
        left: at.dx - 28,
        top: at.dy - 28,
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.colour,
                shape: BoxShape.circle,
              ),
              child: Text(
                '+${widget.points}',
                style: TextStyle(
                  fontFamily: Tokens.fontNumeric,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: widget.onColour,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// One lesson as a large paper card: subject icon and colour, room, time. The lesson
/// that is running is enlarged and marked "Jetzt". Cancelled lessons stay in place,
/// struck through (specs/15).
class KidLessonCard extends StatelessWidget {
  const KidLessonCard({
    required this.lesson,
    required this.icon,
    this.isNow = false,
    super.key,
  });

  final Lesson lesson;
  final IconData icon;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cancelled = lesson.status == LessonStatus.cancelled;
    final note = switch (lesson.status) {
      LessonStatus.cancelled => l10n.kidLessonCancelled,
      LessonStatus.substituted => l10n.kidLessonSubstituted,
      LessonStatus.roomChange => l10n.kidLessonRoomChange,
      _ => null,
    };
    final titleSize = isNow ? 26.0 : null;
    return Semantics(
      label: '${lesson.subject}, ${context.time(lesson.starts)}',
      child: PaperTile(
        tint: lesson.tint,
        struckThrough: cancelled,
        padding: EdgeInsets.all(isNow ? Tokens.space6 : Tokens.space4),
        child: Row(
          children: [
            Icon(icon, size: isNow ? 44 : 34),
            const SizedBox(width: Tokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.subject,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: titleSize,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '${context.time(lesson.starts)} – ${context.time(lesson.ends)}'
                    '${lesson.room == null ? '' : '  ·  ${l10n.kidRoom(lesson.room!)}'}',
                    style: TextStyle(
                      fontFamily: Tokens.fontNumeric,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: theme.textTheme.bodyLarge?.fontSize,
                    ),
                  ),
                  if (note != null)
                    Text(note, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            if (isNow)
              Chip(
                label: Text(l10n.kidNow),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// One child's day of lessons as large cards, with the care row ("Betreuung bis …")
/// under them. A day without school says why: a holiday's name, or simply none.
class KidDayLessons extends StatelessWidget {
  const KidDayLessons({
    required this.day,
    required this.iconOf,
    this.minutesNow,
    super.key,
  });

  final SchoolDay? day;

  /// Subject name → icon. Unknown subjects get the generic school icon.
  final IconData Function(String subject) iconOf;

  /// Minutes since midnight, when the day shown is today; marks the lesson running.
  final int? minutesNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = day;
    if (d == null || !d.hasSchool) {
      return KidCard(
        child: Text(
          d?.holidayName != null
              ? l10n.kidHoliday(d!.holidayName!)
              : l10n.kidNoSchoolToday,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    final lessons = [
      for (final l in d.lessons)
        if (l.kind == LessonKind.lesson) l,
    ];
    return Column(
      children: [
        for (final lesson in lessons)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: KidLessonCard(
              lesson: lesson,
              icon: iconOf(lesson.subject),
              isNow: minutesNow != null && kidLessonIsNow(lesson, minutesNow!),
            ),
          ),
        if (lessons.isEmpty)
          KidCard(
            child: Text(
              l10n.kidNoSchoolToday,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (d.careUntil != null)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space2),
            child: Text(
              l10n.kidCareUntil(context.time(d.careUntil!)),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
      ],
    );
  }
}
