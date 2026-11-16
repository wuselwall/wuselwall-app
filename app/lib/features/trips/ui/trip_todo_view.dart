import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_check_row.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// The Vorbereiten tab (specs/30 "Packing and preparing"): what has to happen before the
/// trip, each optionally some days before it. Once the trip has dates the day is shown as
/// a date; one that has passed is said calmly, without an alarm.
class TripTodoView extends ConsumerWidget {
  const TripTodoView({required this.trip, super.key});

  final Trip trip;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    TripCheck? existing,
  }) async {
    final answer = await showDialog<_TodoAnswer>(
      context: context,
      builder: (_) => _TodoDialog(existing: existing),
    );
    if (answer == null || !context.mounted) return;
    final actions = ref.read(tripActionsProvider);
    final result = await actions.saveCheck(
      existing == null
          ? TripCheck(
              id: TripActions.newId(),
              tripId: trip.id,
              kind: CheckKind.todo,
              title: answer.title,
              dueDaysBefore: answer.days,
            )
          : existing.copyWith(title: answer.title, dueDaysBefore: answer.days),
    );
    if (context.mounted) reportTripResult(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);
    return AsyncValueView<List<TripCheck>>(
      value: ref.watch(tripChecksProvider(trip.id)),
      onRetry: () => ref.invalidate(tripChecksProvider(trip.id)),
      data: (all) {
        final todos = [
          for (final c in all)
            if (c.kind == CheckKind.todo) c,
        ];
        final open = [
          for (final c in todos)
            if (!c.done) c,
        ];
        final done = [
          for (final c in todos)
            if (c.done) c,
        ];

        String? due(TripCheck c) {
          final days = c.dueDaysBefore;
          if (days == null) return null;
          final on = c.dueOn(trip);
          if (on == null) return l10n.tripTodoDaysBefore(days);
          final date = formatTripDate(context, on);
          return !c.done && daysBetween(on, today) > 0
              ? l10n.tripTodoWasDue(date)
              : l10n.tripTodoDue(date);
        }

        Widget row(TripCheck c) => TripCheckRow(
          check: c,
          subtitle: due(c),
          editLabel: l10n.tripTodoEdit,
          onTick: (on) async {
            final result = await ref
                .read(tripActionsProvider)
                .tickCheck(c.id, done: on);
            if (context.mounted) reportTripResult(context, result);
          },
          onEdit: () => _edit(context, ref, existing: c),
          onDelete: () async {
            final result = await ref
                .read(tripActionsProvider)
                .deleteCheck(c.id);
            if (context.mounted) reportTripResult(context, result);
          },
        );

        final add = FilledButton.tonalIcon(
          key: const ValueKey('trip-todo-add'),
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add),
          label: Text(l10n.tripTodoAdd),
        );
        if (todos.isEmpty) {
          return EmptyView(
            illustrated: false,
            scrolls: false,
            message: l10n.tripTodoEmpty,
            actions: [add],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space2),
              child: Text(
                l10n.tripPackProgress(done.length, todos.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Align(alignment: AlignmentDirectional.centerStart, child: add),
            Card(child: Column(children: [for (final c in open) row(c)])),
            if (done.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: Tokens.space3,
                  bottom: Tokens.space1,
                ),
                child: Text(
                  l10n.tripTodoDone,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: context.ww.ink2),
                ),
              ),
              Card(child: Column(children: [for (final c in done) row(c)])),
            ],
          ],
        );
      },
    );
  }
}

typedef _TodoAnswer = ({String title, int? days});

/// Words and, if wanted, how many days before the trip.
class _TodoDialog extends StatefulWidget {
  const _TodoDialog({this.existing});

  final TripCheck? existing;

  @override
  State<_TodoDialog> createState() => _TodoDialogState();
}

class _TodoDialogState extends State<_TodoDialog> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _days = TextEditingController(
    text: widget.existing?.dueDaysBefore?.toString(),
  );

  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final days = int.tryParse(_days.text.trim());
    Navigator.pop<_TodoAnswer>(context, (
      title: title,
      days: days?.clamp(0, 365),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.tripTodoAdd : l10n.tripTodoEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('trip-todo-title'),
              controller: _title,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.tripTodoTitleLabel),
            ),
            TextField(
              key: const ValueKey('trip-todo-days'),
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              decoration: InputDecoration(labelText: l10n.tripTodoDaysLabel),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('trip-todo-save'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
