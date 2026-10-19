import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

/// Basic or Advanced, at the top of each settings screen. Not a guardian action: it only
/// changes what this device shows.
class SettingsViewSwitch extends ConsumerWidget {
  const SettingsViewSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(settingsViewProvider).value ?? SettingsView.basic;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space4),
      child: Semantics(
        label: l10n.settingsViewLabel,
        container: true,
        child: SegmentedButton<SettingsView>(
          key: const ValueKey('settings-view'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: SettingsView.basic,
              label: Text(l10n.settingsViewBasic),
            ),
            ButtonSegment(
              value: SettingsView.advanced,
              label: Text(l10n.settingsViewAdvanced),
            ),
          ],
          selected: {view},
          onSelectionChanged: (s) =>
              ref.read(settingsViewProvider.notifier).select(s.first),
        ),
      ),
    );
  }
}

/// At the end of a Basic screen: more exists, and it still applies.
class MoreSettingsHint extends ConsumerWidget {
  const MoreSettingsHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsViewMoreHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            key: const ValueKey('settings-show-all'),
            onPressed: () => ref
                .read(settingsViewProvider.notifier)
                .select(SettingsView.advanced),
            icon: const Icon(Icons.expand_more),
            label: Text(l10n.settingsViewShowAll),
          ),
        ],
      ),
    );
  }
}
