import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/swipe_stepper.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/board/ui/kiosk_canvas.dart';
import 'package:wuselwall/features/board/ui/kiosk_display.dart';
import 'package:wuselwall/features/board/ui/week_board_view.dart';

/// The kiosk's home: the week board, from the last good snapshot, on a screen that stays
/// awake. Before the first board it waits calmly; if the first fetch fails it says so and
/// offers a retry.
class WeekBoardPage extends ConsumerWidget {
  const WeekBoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      KioskDisplay(child: _body(context, ref));

  Widget _body(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(boardProvider);
    if (snapshot.board case final board?) {
      final ahead = ref.watch(boardNextWeekProvider);
      final next = ref.read(boardNextWeekProvider.notifier);
      final monday = board.weekStart;
      final nextWeek = ahead
          ? ref.watch(
              boardWeekProvider(
                DateTime(monday.year, monday.month, monday.day + 7),
              ),
            )
          : null;
      // A swipe looks a week ahead and back again, as the switch does (specs/09
      // "Gestures"); never further, the wall is about this week.
      return SwipeStepper(
        onPrevious: ahead ? () => next.set(false) : null,
        onNext: ahead ? null : () => next.set(true),
        child: KioskCanvas(
          child: WeekBoardView(
            snapshot: snapshot,
            week: nextWeek?.value,
            placeholder: switch (nextWeek) {
              null || AsyncData() => null,
              AsyncError() => _NextWeekPlaceholder(
                child: Text(
                  context.l10n.boardNextWeekUnavailable,
                  style: boardUi(
                    28,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              _ => const _NextWeekPlaceholder(child: DelayedSpinner()),
            },
          ),
        ),
      );
    }

    final failure = snapshot.failure;
    if (failure != null) {
      return ErrorView(
        error: failure,
        onRetry: () => unawaited(ref.read(boardProvider.notifier).refresh()),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.l10n.boardLoading,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Where next week's columns go while they load or cannot: the switch stays, so the
/// way back is where it was.
class _NextWeekPlaceholder extends StatelessWidget {
  const _NextWeekPlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const BoardDivider(trailing: BoardViewSwitches()),
      Expanded(
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    ],
  );
}
