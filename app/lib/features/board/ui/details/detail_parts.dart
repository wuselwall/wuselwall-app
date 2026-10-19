import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';

/// Words in the detail views: the UI face. Sizes are the kiosk's; nothing under 24.
TextStyle detailUi(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double height = 1.2,
}) => TextStyle(
  fontFamily: Tokens.fontUi,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// Times, dates and numbers: the numeric face with tabular figures, so columns line up.
TextStyle detailNum(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w600,
  double height = 1.2,
}) => TextStyle(
  fontFamily: Tokens.fontNumeric,
  fontFeatures: const [FontFeature.tabularFigures()],
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// The board's inks: primary text is the scheme's `onSurface`, secondary and tertiary
/// come from the shade's palette (`context.ww`).
extension DetailColors on BuildContext {
  Color get ink => Theme.of(this).colorScheme.onSurface;
  Color get accent => Theme.of(this).colorScheme.primary;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Emma · Mittwoch" style joins; empty and null parts are dropped.
String joinParts(Iterable<String?> parts) =>
    parts.whereType<String>().where((p) => p.trim().isNotEmpty).join(' · ');

/// A member's name as the board writes it, or null when the id is unknown.
String? nameOf(BuildContext context, WeekBoard board, String id) {
  final m = board.member(id);
  return m == null ? null : context.memberName(board, m);
}

/// "8–14:25" for a timed event, the all-day label otherwise.
String eventSpan(BuildContext context, BoardEvent e) {
  final start = e.starts;
  if (start == null) return context.l10n.boardAllDay;
  final end = e.ends;
  return end == null ? context.time(start) : context.span(start, end);
}

/// A section heading inside a detail body ("Wer ist wo").
class DetailHeading extends StatelessWidget {
  const DetailHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.space3),
    child: Text(
      text,
      style: detailUi(26, context.ww.ink2, weight: FontWeight.w700),
    ),
  );
}

/// One day of a week-long list: its label in a fixed column, the content beside it.
/// Today is raised (paper ground, primary frame); past days recede to the sunken ground.
class DayRow extends StatelessWidget {
  const DayRow({
    required this.date,
    required this.raised,
    required this.past,
    required this.child,
    super.key,
  });

  final DateTime date;
  final bool raised;
  final bool past;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    // A past day recedes through its ground, never through opacity over its text:
    // specs/17's 4.5:1 holds for past rows as for every other (t_10f0b348).
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space3,
      ),
      decoration: raised
          ? BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border.all(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(14),
            )
          : past
          ? BoxDecoration(
              color: ww.sunken,
              borderRadius: BorderRadius.circular(14),
            )
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: ww.line)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              '${context.weekdayShort(date)} ${context.dayMonth(date)}',
              style: detailNum(
                26,
                raised ? scheme.primary : context.ink,
                weight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The "Morgen einpacken" strip (FR-7.12): the equipment the school asks for, in the
/// warning ground so it is seen from across the kitchen.
class PackStrip extends StatelessWidget {
  const PackStrip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space3,
      ),
      decoration: BoxDecoration(
        color: ww.warningContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.backpack_outlined, color: ww.onWarningContainer, size: 32),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text(
              text,
              style: detailUi(
                26,
                ww.onWarningContainer,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pack strip for [memberId]: today's equipment when [viewedIndex] is today, else
/// tomorrow's (relative to today). Null when nothing is to be packed, or no such day
/// is in reach (today outside the week, or tomorrow past Sunday).
Widget? packStripFor(
  BuildContext context,
  WeekBoard board,
  String memberId, {
  int? viewedIndex,
}) {
  final today = board.todayIndex;
  if (today == null) return null;
  final l10n = context.l10n;
  if (viewedIndex == today) {
    final items =
        board.days[today].school[memberId]?.equipment ?? const <String>[];
    if (items.isEmpty) return null;
    return PackStrip(l10n.boardPackToday(items.join(', ')));
  }
  final tomorrow = today + 1;
  if (tomorrow >= board.days.length) return null;
  final items =
      board.days[tomorrow].school[memberId]?.equipment ?? const <String>[];
  if (items.isEmpty) return null;
  return PackStrip(l10n.boardPackTomorrow(items.join(', ')));
}

/// Who is eating: a filled dot for each member at the table, a hollow one for the rest,
/// each with the name beside it (the "isst mit" dots, specs/09).
class EatingDots extends StatelessWidget {
  const EatingDots({required this.board, required this.eating, super.key});

  final WeekBoard board;
  final Set<String> eating;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    return Wrap(
      spacing: Tokens.space6,
      runSpacing: Tokens.space2,
      children: [
        for (final m in board.members)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberDot(
                memberColor: m.color,
                filled: eating.contains(m.id),
                size: 20,
                semanticLabel: eating.contains(m.id)
                    ? l10n.boardEating(context.memberName(board, m))
                    : l10n.boardNotEating(context.memberName(board, m)),
              ),
              const SizedBox(width: Tokens.space2),
              // A long name wraps within the width the Wrap offers instead of
              // running past it at large text (t_10f0b348).
              Flexible(
                child: Text(
                  context.memberName(board, m),
                  style: detailUi(
                    24,
                    eating.contains(m.id) ? context.ink : ww.ink3,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A meal's facts: slot and time, the dish, who cooks, who is eating, the guests.
/// A meal with no dish still shows its slot and who is eating.
class MealFacts extends StatelessWidget {
  const MealFacts({required this.board, required this.meal, super.key});

  final WeekBoard board;
  final BoardMeal? meal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final meal = this.meal;
    if (meal == null) {
      return Text(l10n.boardMealNothingPlanned, style: detailUi(26, ww.ink3));
    }
    final cook = meal.cookId == null
        ? null
        : nameOf(context, board, meal.cookId!);
    final time = meal.time;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.mealSlotLabel(meal.slot),
              style: detailUi(26, ww.ink2, weight: FontWeight.w700),
            ),
            if (time != null) ...[
              const SizedBox(width: Tokens.space3),
              Text(
                context.time(time),
                style: detailNum(26, context.ink, weight: FontWeight.w700),
              ),
            ],
          ],
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          meal.title ?? l10n.boardMealNothingPlanned,
          style: detailUi(
            28,
            meal.isPlanned ? context.ink : ww.ink3,
            weight: FontWeight.w800,
          ),
        ),
        if (cook != null)
          Text(l10n.boardMealCook(cook), style: detailUi(24, ww.ink2)),
        const SizedBox(height: Tokens.space3),
        EatingDots(board: board, eating: meal.eating),
        if (meal.guests > 0)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space2),
            child: Text(
              l10n.boardMealGuests(meal.guests),
              style: detailUi(24, ww.ink2),
            ),
          ),
      ],
    );
  }
}
