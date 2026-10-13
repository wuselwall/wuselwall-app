import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
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
/// the sign of a movement ("+5", "−3").
class PointsCoin extends StatelessWidget {
  const PointsCoin({
    required this.points,
    this.fontSize = 16,
    this.signed = false,
    super.key,
  });

  final int points;
  final double fontSize;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final text = signed && points > 0 ? '+$points' : '$points';
    return Semantics(
      label: context.l10n.tasksPointsCount(points),
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
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontFamily: Tokens.fontNumeric,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: ww.onPoints,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// The task's picture: its emoji from `taskIcons`, or a neutral tick when it has none.
class TaskGlyph extends StatelessWidget {
  const TaskGlyph({this.iconKey, this.size = 28, super.key});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = taskIconGlyph(iconKey);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size * 1.4,
        child: Center(
          child: glyph == null
              ? Icon(
                  Icons.task_alt,
                  size: size,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : Text(glyph, style: TextStyle(fontSize: size)),
        ),
      ),
    );
  }
}

/// "5 Punkte · Pflicht": a line of facts about one task.
String taskKindLabel(BuildContext context, TaskKind kind) => switch (kind) {
  TaskKind.duty => context.l10n.tasksKindDuty,
  TaskKind.bonus => context.l10n.tasksKindBonus,
};

/// The streak of [profileId] on [definitionId] as "🔥 3", or null when there is none.
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
