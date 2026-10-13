import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// The week's hot meals, one row per day, with who is eating. Today is raised, past
/// days recede.
///
/// The dots are the kiosk's one meal correction (specs/09, specs/07): a tap on a member's
/// dot flips that person for the day's warm meal, as the acting profile, through
/// `meal_eating_set`. With nobody acting, the dots do nothing and the acting bar shows.
class MealWeekDetailBody extends ConsumerStatefulWidget {
  const MealWeekDetailBody({required this.board, super.key});

  final WeekBoard board;

  @override
  ConsumerState<MealWeekDetailBody> createState() => _MealWeekDetailState();
}

class _MealWeekDetailState extends ConsumerState<MealWeekDetailBody> {
  /// `date|member` keys with a write in flight, so a second tap waits for the first.
  final _busy = <String>{};

  Future<void> _toggle(BoardDay day, BoardMeal meal, BoardMember member) async {
    final acting = ref.read(actingProfileProvider);
    if (acting == null) return;
    final key = '${day.date}|${member.id}';
    if (!_busy.add(key)) return;
    setState(() {});
    final eating = !meal.eating.contains(member.id);
    final result = await ref
        .read(mealsRepositoryProvider)
        .setEating(
          actor: acting,
          date: day.date,
          slot: meal.slot == MealSlot.lunch ? PlanSlot.lunch : PlanSlot.dinner,
          profileId: member.id,
          eating: eating,
        );
    if (!mounted) return;
    _busy.remove(key);
    setState(() {});
    switch (result) {
      case Ok():
        await ref.read(boardProvider.notifier).refresh();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final acting = ref.watch(actingProfileProvider);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Tokens.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (acting != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space4),
                    child: Text(
                      context.l10n.mealsKioskHint,
                      style: detailUi(24, context.ww.ink2),
                    ),
                  ),
                for (final day in board.days)
                  DayRow(
                    date: day.date,
                    raised: isSameDay(day.date, board.today),
                    past: day.date.isBefore(board.today),
                    child: _MealFacts(
                      board: board,
                      meal: day.meal,
                      canEdit: acting != null,
                      busy: {
                        for (final m in board.members)
                          if (_busy.contains('${day.date}|${m.id}')) m.id,
                      },
                      onToggle: (member, meal) => _toggle(day, meal, member),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (acting == null) const ActingProfileBar(),
      ],
    );
  }
}

/// A meal's facts: slot and time, the dish, who cooks, who is eating (tappable), the
/// guests. A meal with no dish still shows its slot and who is eating.
class _MealFacts extends StatelessWidget {
  const _MealFacts({
    required this.board,
    required this.meal,
    required this.canEdit,
    required this.busy,
    required this.onToggle,
  });

  final WeekBoard board;
  final BoardMeal? meal;
  final bool canEdit;
  final Set<String> busy;
  final void Function(BoardMember member, BoardMeal meal) onToggle;

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
        Wrap(
          spacing: Tokens.space6,
          runSpacing: Tokens.space2,
          children: [
            for (final m in board.members)
              _EatingDot(
                member: m,
                board: board,
                eating: meal.eating.contains(m.id),
                busy: busy.contains(m.id),
                enabled: canEdit,
                onTap: () => onToggle(m, meal),
              ),
          ],
        ),
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

/// One member's dot and name as a kiosk touch target (56 px tall).
class _EatingDot extends StatelessWidget {
  const _EatingDot({
    required this.member,
    required this.board,
    required this.eating,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final BoardMember member;
  final WeekBoard board;
  final bool eating;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = context.memberName(board, member);
    final ww = context.ww;
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(UiRegister.kiosk.radius),
        onTap: enabled && !busy ? onTap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: UiRegister.kiosk.touchTarget,
            minWidth: UiRegister.kiosk.touchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberDot(
                memberColor: member.color,
                filled: eating,
                size: 24,
                semanticLabel: eating
                    ? l10n.boardEating(name)
                    : l10n.boardNotEating(name),
              ),
              const SizedBox(width: Tokens.space2),
              Text(
                name,
                style: detailUi(
                  24,
                  eating ? context.ink : ww.ink3,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
