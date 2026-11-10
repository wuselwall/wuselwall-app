import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';

/// The client-side row of the getting-started card: "Erinnerungen einschalten". Its tap
/// is the only place the system permission prompt appears (specs/20, specs/09).
class ReminderStartRow extends ConsumerWidget {
  const ReminderStartRow({this.done = false, super.key});

  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dismiss = TextButton(
      onPressed: () => unawaited(dismissReminderCard(ref)),
      child: Text(l10n.todayStartNotNeeded),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            420;
        final tile = ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: Tokens.space1,
          leading: Icon(
            Icons.notifications_active_outlined,
            color: done ? context.ww.success : theme.colorScheme.onSurface,
          ),
          title: Text(
            l10n.reminderStartLabel,
            style: TextStyle(
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
          trailing: done
              ? Icon(Icons.check_circle, color: context.ww.success)
              : null,
          onTap: done ? null : () => unawaited(_enable(context, ref)),
        );
        if (done) return tile;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [tile, dismiss],
          );
        }
        return Row(
          children: [
            Expanded(child: tile),
            dismiss,
          ],
        );
      },
    );
  }
}

Future<void> _enable(BuildContext context, WidgetRef ref) async {
  final granted = await enableReminders(ref);
  if (!context.mounted || granted) return;
  context.showMessage(context.l10n.reminderDeniedNote);
}
