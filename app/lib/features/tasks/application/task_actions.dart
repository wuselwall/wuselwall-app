import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/confetti.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Ticks [task] as the acting profile. Without one, nothing is sent: the caller shows
/// the "who are you?" bar. Adult screens offer "Rückgängig" in the snackbar; the kiosk
/// does not, because its snackbar sits under the detail frame.
///
/// Takes the [ProviderContainer], not a `WidgetRef`, so the undo action keeps working
/// after the tapped widget has gone.
Future<void> tickTask(
  BuildContext context,
  ProviderContainer container,
  TaskInstance task, {
  bool offerUndo = true,
}) async {
  final l10n = context.l10n;
  final actor = container.read(actingProfileProvider);
  if (actor == null) {
    context.showMessage(l10n.actingWho);
    return;
  }
  // Whether this tick finishes that person's chores for today (specs/26).
  final whose = task.assignedProfileId ?? actor;
  final last = (container.read(tasksTodayProvider).value ?? const [])
      .where(
        (t) =>
            (t.assignedProfileId ?? actor) == whose &&
            t.id != task.id &&
            !t.isTicked,
      )
      .isEmpty;
  final celebration = container.read(celebrationProvider);
  final result = await container
      .read(tasksRepositoryProvider)
      .complete(actor: actor, instanceId: task.id);
  invalidateTasks(container.invalidate);
  if (!context.mounted) return;
  switch (result) {
    case Err(:final failure):
      context.showFailure(failure);
    case Ok():
      // The last chore is a moment on the wall and the kid tablet; on a grown-up's
      // phone it stays a tick (specs/26 "Celebrations"). Each person's day celebrates
      // once, and not over a burst that is still running.
      if (last &&
          container.read(uiRegisterProvider) != UiRegister.adult &&
          celebration.claimMoment(Celebration.lastChoreOf(whose))) {
        final ww = context.ww;
        showConfetti(
          context,
          colors: [
            for (final c in container.read(wuselTuftsProvider))
              ww.member(c).ink,
            ww.points,
          ],
        );
        unawaited(celebration.cue(Cue.fertig));
      } else {
        unawaited(celebration.cue(Cue.tick));
      }
      if (!offerUndo) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.tasksCompletedSnack(task.title)),
            action: SnackBarAction(
              label: l10n.tasksUndo,
              onPressed: () =>
                  unawaited(_undo(container, messenger, l10n, actor, task.id)),
            ),
          ),
        );
  }
}

Future<void> _undo(
  ProviderContainer container,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String actor,
  String instanceId,
) async {
  final result = await container
      .read(tasksRepositoryProvider)
      .undo(actor: actor, instanceId: instanceId);
  invalidateTasks(container.invalidate);
  if (result case Err(:final failure)) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.message(l10n))));
  }
}
