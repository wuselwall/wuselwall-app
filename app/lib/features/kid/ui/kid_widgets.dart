import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';

/// Which decoration colour the kid cards below take for their offset shadow: each kid
/// tab sets its own (specs/26 "The kid register's sticker skin").
class KidDecorScope extends InheritedWidget {
  const KidDecorScope({required this.decor, required super.child, super.key});

  final Decor decor;

  static Decor of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KidDecorScope>()?.decor ??
      Decor.sun;

  @override
  bool updateShouldNotify(KidDecorScope old) => old.decor != decor;
}

/// Large, friendly surfaces of the kid register in the sticker skin (specs/26): radius
/// 22, a 2 px outline, and a minimum height that is a touch target on its own. A card
/// that can be pressed stands on an offset shadow in its tab's decoration colour and
/// moves down onto it when pressed, so the seven-year-old sees what can be tapped.
class KidCard extends StatefulWidget {
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

  /// An outline in the primary colour: today, or the card the child is on.
  final bool highlight;

  static const radius = 22.0;
  static const _lift = 4.0;

  @override
  State<KidCard> createState() => _KidCardState();
}

class _KidCardState extends State<KidCard> {
  bool _pressed = false;

  void _press(bool down) {
    if (widget.onTap == null || down == _pressed) return;
    setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ww = context.ww;
    final tappable = widget.onTap != null;
    final outline = widget.highlight
        ? scheme.primary
        : ww.shade == Shade.light
        ? scheme.onSurface.withValues(alpha: 0.85)
        : ww.line;
    final shadow = ww.decor(KidDecorScope.of(context)).withValues(alpha: 0.6);
    final moving = motionAllowed(context);
    final down = _pressed ? KidCard._lift - 1 : 0.0;
    final card = Material(
      color: widget.color ?? scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KidCard.radius),
        side: BorderSide(color: outline, width: 2),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: _press,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: widget.child,
        ),
      ),
    );
    if (!tappable) return card;
    return Padding(
      padding: const EdgeInsets.only(bottom: KidCard._lift),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: down),
        duration: moving ? Tokens.motionStandard : Duration.zero,
        curve: Curves.easeOutBack,
        builder: (context, offset, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KidCard.radius),
            boxShadow: [
              BoxShadow(color: shadow, offset: const Offset(0, KidCard._lift)),
            ],
          ),
          position: DecorationPosition.background,
          child: Transform.translate(offset: Offset(0, offset), child: child),
        ),
        child: card,
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
  const KidBalancePill({required this.balance, this.loaded = true, super.key});

  final int balance;

  /// False while the balance is still loading: the first real value then appears at
  /// once instead of counting up from zero each time the page opens.
  final bool loaded;

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
    if (kidReduceMotion(context) || !oldWidget.loaded) {
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

/// A coin that flies from [from] (or the point [fromPoint], Wusel's hand) to [to] over
/// 600 ms, `easeOutCubic`, then goes. Shown in the app's overlay, so it survives the
/// card that launched it. Does nothing when either anchor is not on screen.
/// [onLanded] is called when the coin has arrived, or at once when it does not fly.
void kidFlyCoin(
  BuildContext context, {
  GlobalKey? from,
  Offset? fromPoint,
  required GlobalKey to,
  required int points,
  VoidCallback? onLanded,
}) {
  final overlay = Overlay.maybeOf(context);
  final start = fromPoint ?? (from == null ? null : _centreOf(from));
  final end = _centreOf(to);
  if (overlay == null || start == null || end == null) {
    onLanded?.call();
    return;
  }
  final ww = context.ww;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingCoin(
      start: start,
      end: end,
      fromHand: fromPoint != null,
      points: points,
      colour: ww.points,
      onColour: ww.onPoints,
      onDone: () {
        entry.remove();
        onLanded?.call();
      },
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
    required this.fromHand,
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

  /// From Wusel's hand: the coin grows out of the small one Wusel held, eases out
  /// of the hand rather than shooting off, and shrinks into the pill.
  final bool fromHand;

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
      final v = _controller.value;
      final at = Offset.lerp(
        widget.start,
        widget.end,
        (widget.fromHand ? Curves.easeInOutCubic : Curves.easeOutCubic)
            .transform(v),
      )!;
      final scale = !widget.fromHand
          ? 1.0
          : v < 0.3
          ? 0.3 + 0.7 * Curves.easeOutBack.transform(v / 0.3)
          : v > 0.8
          ? 1 - 0.45 * ((v - 0.8) / 0.2)
          : 1.0;
      return Positioned(
        left: at.dx - 28,
        top: at.dy - 28,
        child: Transform.scale(
          scale: scale,
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
                  // The time span stays on one line (non-breaking spaces); a
                  // narrow card breaks before the room instead.
                  Text(
                    '${context.time(lesson.starts)}\u00A0–\u00A0${context.time(lesson.ends)}'
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
