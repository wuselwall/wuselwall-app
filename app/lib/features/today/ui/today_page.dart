import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/tasks/application/task_actions.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/ui/getting_started_card.dart';
import 'package:wuselwall/features/today/ui/notice_cards.dart';

/// The adult home's first tab (specs/09 "Screens by register"): the setup card, then
/// what today holds for the acting profile. Each block hides when it is empty; when
/// nothing is left, one line says so.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(todayAgendaProvider);
    final shoppingOpen = ref.watch(defaultShoppingOpenProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(todayAgendaProvider)
          ..invalidate(gettingStartedProvider)
          ..invalidate(noticesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space6,
        ),
        children: [
          const NoticeCards(),
          const GettingStartedCard(),
          AsyncValueView<TodayAgenda>(
            value: agenda,
            onRetry: () => ref.invalidate(todayAgendaProvider),
            data: (a) => _Agenda(agenda: a, shoppingOpen: shoppingOpen),
          ),
        ],
      ),
    );
  }
}

class _Agenda extends ConsumerWidget {
  const _Agenda({required this.agenda, required this.shoppingOpen});

  final TodayAgenda agenda;
  final int shoppingOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (agenda.isEmpty && shoppingOpen == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space6),
        child: Text(l10n.todayEmpty, textAlign: TextAlign.center),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (agenda.events.isNotEmpty) ...[
          _Header(title: l10n.todayAgendaTitle),
          _Block(
            children: [for (final e in agenda.events) _EventRow(event: e)],
          ),
        ],
        if (agenda.tasks.isNotEmpty) ...[
          _Header(title: l10n.todayTasksTitle),
          _Block(children: [for (final t in agenda.tasks) _TaskRow(task: t)]),
        ],
        if (agenda.warmMeal case final meal?) ...[
          _Header(title: l10n.todayMealTitle),
          _Block(
            children: [
              ListTile(
                leading: const Icon(Icons.restaurant_outlined),
                title: Text(
                  l10n.todayMealLine(
                    agenda.warmSlot == PlanSlot.dinner
                        ? l10n.mealsSlotDinner
                        : l10n.mealsSlotLunch,
                    meal.title ?? '',
                  ),
                ),
              ),
            ],
          ),
        ],
        if (shoppingOpen > 0) ...[
          _Header(title: l10n.todayShoppingTitle),
          _Block(
            children: [
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: Text(l10n.todayShoppingOpen(shoppingOpen)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    ref.read(homeTabProvider.notifier).select(HomeTab.shopping),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Tokens.space4, bottom: Tokens.space2),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: Tokens.space1),
    child: Column(children: children),
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final Occurrence event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final start = event.localStarts;
    final when = start == null
        ? l10n.todayAllDay
        : MaterialLocalizations.of(context)
              .formatTimeOfDay(start, alwaysUse24HourFormat: true);
    return ListTile(
      leading: SizedBox(
        width: 56,
        child: Text(
          when,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      title: Text(event.title),
      subtitle: event.location == null ? null : Text(event.location!),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final TaskInstance task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: TaskGlyph(iconKey: task.iconKey),
      title: Text(task.title),
      subtitle: task.points > 0
          ? PointsCoin(points: task.points, fontSize: 14)
          : null,
      trailing: IconButton(
        tooltip: l10n.tasksActionTick,
        iconSize: 30,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: const Icon(Icons.radio_button_unchecked),
        onPressed: () => unawaited(
          tickTask(context, ProviderScope.containerOf(context), task),
        ),
      ),
    );
  }
}
