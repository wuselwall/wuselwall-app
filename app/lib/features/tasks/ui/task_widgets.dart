import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/animated_count.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// A member's initial in a circle of their ink. [inverted] puts the circle on
/// `onInk` instead, for a header that is itself filled with the ink.
class TaskAvatar extends StatelessWidget {
  const TaskAvatar({
    required this.name,
    required this.color,
    this.size = 40,
    this.inverted = false,
    super.key,
  });

  final String name;

  /// The member's stored colour; resolved with `context.ww.member`.
  final Color color;
  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final mc = context.ww.member(color);
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final ground = inverted ? mc.onInk : mc.ink;
    final text = inverted ? mc.ink : mc.onInk;
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ground, shape: BoxShape.circle),
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: Tokens.fontUi,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.5,
            color: text,
          ),
        ),
      ),
    );
  }
}

/// Points as a gold coin with the number on it (`context.ww.points`). [signed] shows
/// the sign of a movement ("+5", "−3"). A balance [counts] to its new value when it
/// changes ([AnimatedCount]). A lone number on a coin does not say what it counts, so
/// the screen reader and the tooltip (hover, long press) say "5 Punkte".
class PointsCoin extends StatelessWidget {
  const PointsCoin({
    required this.points,
    this.fontSize = 16,
    this.signed = false,
    this.counts = false,
    this.withUnit = false,
    super.key,
  });

  final int points;
  final double fontSize;
  final bool signed;
  final bool counts;

  /// Writes the unit on the coin ("2 Punkte", "1 Punkt"), as the kid card says it:
  /// for the adult lists, where a bare number beside "Pflicht" does not say what it
  /// counts. Not with [signed] or [counts].
  final bool withUnit;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    String written(int points) => signed && points > 0 ? '+$points' : '$points';
    final style = TextStyle(
      fontFamily: Tokens.fontNumeric,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: ww.onPoints,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final label = context.l10n.tasksPointsCount(points);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.6,
            vertical: fontSize * 0.2,
          ),
          decoration: BoxDecoration(
            color: ww.points,
            borderRadius: BorderRadius.circular(999),
          ),
          child: counts
              ? AnimatedCount(value: points, style: style, format: written)
              : Text(
                  withUnit && !signed ? label : written(points),
                  maxLines: 1,
                  style: style,
                ),
        ),
      ),
    );
  }
}

/// The picture of a task, reward or badge icon key, or null when the key is unknown.
String? taskIconAsset(String? key) => key != null && taskIconKeys.contains(key)
    ? 'assets/emoji/tasks/$key.png'
    : null;

/// What the icon shows, for the chooser's tooltip and screen readers.
String taskIconName(AppLocalizations l10n, String key) => switch (key) {
  'dishes' => l10n.taskIcon_dishes,
  'table' => l10n.taskIcon_table,
  'trash' => l10n.taskIcon_trash,
  'bed' => l10n.taskIcon_bed,
  'dog' => l10n.taskIcon_dog,
  'plant' => l10n.taskIcon_plant,
  'bike' => l10n.taskIcon_bike,
  'book' => l10n.taskIcon_book,
  'laundry' => l10n.taskIcon_laundry,
  'teeth' => l10n.taskIcon_teeth,
  'shopping' => l10n.taskIcon_shopping,
  'cooking' => l10n.taskIcon_cooking,
  'car' => l10n.taskIcon_car,
  'toys' => l10n.taskIcon_toys,
  'star' => l10n.taskIcon_star,
  'cinema' => l10n.taskIcon_cinema,
  'moon' => l10n.taskIcon_moon,
  'trip' => l10n.taskIcon_trip,
  _ => l10n.tasksFieldIcon,
};

/// The task's picture: its bundled picture for [iconKey], or a neutral tick when it has none.
class TaskGlyph extends StatelessWidget {
  const TaskGlyph({this.iconKey, this.size = 28, super.key});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = taskIconAsset(iconKey);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size * 1.4,
        child: Center(
          child: asset == null
              ? Icon(
                  Icons.task_alt,
                  size: size,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : EmojiPicture(asset, size: size),
        ),
      ),
    );
  }
}

/// "🔥 3" as a picture and the count; screen readers hear "3 days in a row".
class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.days, this.style, super.key});

  final int days;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final size =
        (style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14) *
        1.1;
    return Semantics(
      label: context.l10n.tasksStreakDays(days),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmojiPicture(emojiFire, size: size),
          const SizedBox(width: 2),
          Text('$days', style: style, maxLines: 1),
        ],
      ),
    );
  }
}

/// "5 Punkte · Pflicht": a line of facts about one task.
String taskKindLabel(BuildContext context, TaskKind kind) => switch (kind) {
  TaskKind.duty => context.l10n.tasksKindDuty,
  TaskKind.bonus => context.l10n.tasksKindBonus,
};

/// The streak of [profileId] on [definitionId], or null when there is none.
Streak? streakOf(
  Iterable<Streak> streaks,
  String? profileId,
  String? definitionId,
) {
  if (profileId == null || definitionId == null) return null;
  for (final s in streaks) {
    if (s.profileId == profileId &&
        s.definitionId == definitionId &&
        s.currentLength > 0) {
      return s;
    }
  }
  return null;
}

/// A chore's tick that pops on the snappy spring when it turns on while shown, growing
/// from [from] to full size and overshooting a little (specs/26 "Celebrations"). A tick
/// that was on when it appeared, or one that turns off, sits at rest; under reduced
/// motion it lands at once (specs/26 "Motion").
class TickPop extends StatefulWidget {
  const TickPop({
    required this.ticked,
    required this.child,
    this.from = 0.5,
    super.key,
  });

  final bool ticked;
  final Widget child;

  /// Where the pop starts: half size on the wall, a smaller step on a phone.
  final double from;

  @override
  State<TickPop> createState() => _TickPopState();
}

class _TickPopState extends State<TickPop> with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  @override
  void didUpdateWidget(TickPop old) {
    super.didUpdateWidget(old);
    if (old.ticked == widget.ticked) return;
    if (!widget.ticked || !motionAllowed(context)) {
      _scale.value = 1;
      return;
    }
    unawaited(
      _scale.animateWith(
        SpringSimulation(Tokens.springSnappy, widget.from, 1, 0),
      ),
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

/// Whether a shown tick on [task] still waits for a guardian's check: ticked (here or
/// on the server) on a chore that needs verification and not verified yet
/// (specs/06 "Verification").
bool awaitsCheckShown(bool ticked, TaskInstance task) =>
    ticked &&
    task.requiresVerification &&
    task.status != InstanceStatus.verified;

/// The tick at the end of an adult chore row: an open circle to tick, the green
/// check once done, or an hourglass in ink2 while the chore [waiting]s for a
/// guardian's check — that is not done yet, so it does not look like it (specs/06
/// "Verification").
class TaskTickButton extends StatelessWidget {
  const TaskTickButton({
    required this.ticked,
    required this.onTick,
    this.waiting = false,
    super.key,
  });

  final bool ticked;
  final bool waiting;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    return IconButton(
      tooltip: waiting
          ? l10n.tasksWaitingApproval
          : ticked
          ? l10n.tasksDone
          : l10n.tasksActionTick,
      iconSize: 30,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: TickPop(
        ticked: ticked,
        from: 0.8,
        child: Icon(
          waiting
              ? Icons.hourglass_top_rounded
              : ticked
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: waiting
              ? ww.ink2
              : ticked
              ? ww.success
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onPressed: ticked ? null : onTick,
    );
  }
}

/// A chore's title in a list tile: struck through and muted once ticked, the colour
/// fading over 150 ms (specs/17 "Motion"; at once under reduced motion). Builds on the
/// tile's own title style.
class TickedTitle extends StatelessWidget {
  const TickedTitle({required this.title, required this.ticked, super.key});

  final String title;
  final bool ticked;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    return AnimatedDefaultTextStyle(
      style: base.copyWith(
        decoration: ticked ? TextDecoration.lineThrough : TextDecoration.none,
        color: ticked
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : base.color,
      ),
      duration: motionAllowed(context) ? Tokens.motionStandard : Duration.zero,
      curve: Curves.easeOutCubic,
      child: Text(title),
    );
  }
}
