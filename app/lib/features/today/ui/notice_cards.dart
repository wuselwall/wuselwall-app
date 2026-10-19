import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// The notices at the top of the adult Today tab (specs/20 J2, J4): "Julia ist
/// beigetreten" for guardians, "Neu angemeldet: ‹Gerät›" on the account's other
/// phones. Each is dismissed with "Gesehen" and links to where the household can act:
/// Einstellungen lists the members and, with the revoke action, the devices.
class NoticeCards extends ConsumerWidget {
  const NoticeCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(noticesProvider).value ?? const <AppNotice>[];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [for (final notice in notices) _NoticeCard(notice: notice)],
    );
  }
}

class _NoticeCard extends ConsumerWidget {
  const _NoticeCard({required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (icon, text, linkLabel) = switch (notice.kind) {
      NoticeKind.join => (
        Icons.person_add_alt_1,
        l10n.todayNoticeJoined(notice.name),
        l10n.todayNoticeMembers,
      ),
      NoticeKind.signIn => (
        Icons.phone_iphone,
        l10n.todayNoticeSignIn(notice.name),
        l10n.todayNoticeDevices,
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(context.push<void>(Routes.settings)),
              child: Text(linkLabel),
            ),
            TextButton(
              onPressed: () => unawaited(_dismiss(context, ref)),
              child: Text(l10n.todayNoticeDismiss),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context);
    final actor = container.read(actingProfileProvider);
    if (actor == null) return;
    final result = await ref
        .read(noticesRepositoryProvider)
        .dismiss(actor: actor, key: notice.key);
    container.invalidate(noticesProvider);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}
