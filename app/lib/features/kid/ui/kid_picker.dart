import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// "Wer bist du?" on a shared kid device: one big avatar per member. Tapping one makes
/// that person the acting profile, and the screen behind it appears.
class KidPicker extends ConsumerWidget {
  const KidPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider);
    return Padding(
      key: const ValueKey('kid-picker'),
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        children: [
          const SizedBox(height: Tokens.space6),
          Text(
            l10n.kidWhoAreYou,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Tokens.space8),
          Expanded(
            child: AsyncValueView<List<Member>>(
              value: members,
              onRetry: () => ref.invalidate(membersProvider),
              data: (list) => SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Tokens.space8,
                  runSpacing: Tokens.space8,
                  children: [
                    for (final m in list.where((m) => m.active))
                      _Choice(
                        member: m,
                        onTap: () => ref
                            .read(actingProfileProvider.notifier)
                            .select(m.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.member, required this.onTap});

  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ww.member(member.color);
    return Semantics(
      button: true,
      focusable: true,
      onTap: onTap,
      label: member.displayName,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('kid-pick-${member.id}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.ink,
                shape: BoxShape.circle,
              ),
              child: Text(
                member.initial,
                style: TextStyle(
                  fontFamily: Tokens.fontUi,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: colors.onInk,
                ),
              ),
            ),
            const SizedBox(height: Tokens.space2),
            SizedBox(
              width: 150,
              child: Text(
                member.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
