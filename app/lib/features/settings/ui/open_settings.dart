import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/member_circle.dart';

/// What the settings gear does. On the kitchen wall with nobody selected it first asks who
/// is asking, makes that person the acting one and then opens settings; Cancel opens
/// nothing. Everywhere else it opens settings (the router decides what that person may
/// see, see `settingsAccessProvider`).
Future<void> openSettings(BuildContext context, WidgetRef ref) async {
  final device = ref.read(deviceProvider).value;
  if (device?.deviceClass == DeviceClass.kiosk &&
      ref.read(actingProfileProvider) == null) {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => const WhoAreYouDialog(),
    );
    if (picked == null || !context.mounted) return;
    ref.read(actingProfileProvider.notifier).select(picked);
  }
  if (!context.mounted) return;
  await context.push<void>(Routes.settings);
}

/// "Who are you?" for the wall: one big avatar per active member, names at the wall's
/// reading size (nothing under 24 px). Pops with the member's id, or null on Cancel.
class WhoAreYouDialog extends ConsumerWidget {
  const WhoAreYouDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider);
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('who-are-you'),
      title: Text(l10n.actingWho, style: theme.textTheme.headlineMedium),
      content: SizedBox(
        width: 640,
        child: members.when(
          data: (list) => SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: Tokens.space6,
              runSpacing: Tokens.space6,
              children: [
                for (final m in list.where((m) => m.active)) _Choice(member: m),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('who-are-you-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(96, 56)),
          child: Text(l10n.cancel, style: theme.textTheme.titleLarge),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    void pick() => Navigator.of(context).pop(member.id);
    return Semantics(
      button: true,
      focusable: true,
      onTap: pick,
      label: member.displayName,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('who-pick-${member.id}'),
        customBorder: const CircleBorder(),
        onTap: pick,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberCircle(member: member, size: 96),
            const SizedBox(height: Tokens.space2),
            SizedBox(
              width: 140,
              child: Text(
                member.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
