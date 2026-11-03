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
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// The notices at the top of the adult Today tab (specs/20 J2, J4): "Julia ist
/// beigetreten" for guardians, "Neu angemeldet: ‹Gerät›" on the account's other
/// phones, and a guardian's reset of someone's second factor or password (to that person
/// and the other guardians). Each is dismissed with "Gesehen" and links to where the
/// household can act: Einstellungen lists the members and, with the revoke action, the
/// devices.
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
    // A reset names the person it was done for: "you" when that is the viewer.
    final forMe =
        notice.profileId != null &&
        notice.profileId == ref.watch(actingProfileProvider);
    final target =
        (ref.watch(membersProvider).value ?? const [])
            .where((m) => m.id == notice.profileId)
            .map((m) => m.displayName)
            .firstOrNull ??
        '';
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
      NoticeKind.mfaReset => (
        Icons.lock_reset,
        forMe
            ? l10n.accountNoticeMfaResetYou(notice.name)
            : l10n.accountNoticeMfaReset(notice.name, target),
        l10n.todayNoticeMembers,
      ),
      NoticeKind.passwordResetIssued => (
        Icons.password,
        forMe
            ? l10n.accountNoticePasswordResetYou(notice.name)
            : l10n.accountNoticePasswordReset(notice.name, target),
        l10n.todayNoticeMembers,
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final effectiveWidth =
                constraints.maxWidth /
                MediaQuery.textScalerOf(context).scale(1);
            final stackActions = effectiveWidth < 500;
            final message = Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            );
            final settingsButton = TextButton(
              onPressed: () => unawaited(context.push<void>(Routes.settings)),
              child: Text(linkLabel),
            );
            final dismissButton = TextButton(
              onPressed: () => unawaited(_dismiss(context, ref)),
              child: Text(l10n.todayNoticeDismiss),
            );

            if (stackActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: theme.colorScheme.primary),
                      const SizedBox(width: Tokens.space3),
                      Expanded(child: message),
                    ],
                  ),
                  const SizedBox(height: Tokens.space1),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: Tokens.space1,
                    children: [settingsButton, dismissButton],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: Tokens.space3),
                Expanded(child: message),
                settingsButton,
                dismissButton,
              ],
            );
          },
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
