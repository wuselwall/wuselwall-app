import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
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
    if (snapshot.board != null) {
      return KioskCanvas(child: WeekBoardView(snapshot: snapshot));
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
