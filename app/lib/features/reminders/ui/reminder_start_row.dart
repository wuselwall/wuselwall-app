import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';

/// The client-side row of the getting-started card: "Erinnerungen einschalten". Its tap
/// is the only place the system permission prompt appears (specs/20, specs/09).
class ReminderStartRow extends ConsumerWidget {
  const ReminderStartRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: Tokens.space1,
      leading: Icon(
        Icons.notifications_active_outlined,
        color: theme.colorScheme.onSurface,
      ),
      title: Text(l10n.reminderStartLabel),
      trailing: TextButton(
        onPressed: () => unawaited(dismissReminderCard(ref)),
        child: Text(l10n.todayStartNotNeeded),
      ),
      onTap: () => unawaited(_enable(context, ref)),
    );
  }
}

Future<void> _enable(BuildContext context, WidgetRef ref) async {
  final granted = await enableReminders(ref);
  if (!context.mounted || granted) return;
  context.showMessage(context.l10n.reminderDeniedNote);
}
