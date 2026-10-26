import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

/// The "Advanced" toggle in the app bar of each settings screen: off shows Basic, on
/// shows everything. Not a guardian action: it only changes what this device shows.
class SettingsViewSwitch extends ConsumerWidget {
  const SettingsViewSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final advanced = ref.watch(showAdvancedSettingsProvider);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Tokens.space2),
      child: Center(
        child: Tooltip(
          message: l10n.settingsViewLabel,
          child: FilterChip(
            key: const ValueKey('settings-view'),
            label: Text(l10n.settingsViewAdvanced),
            selected: advanced,
            visualDensity: VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (on) => ref
                .read(settingsViewProvider.notifier)
                .select(on ? SettingsView.advanced : SettingsView.basic),
          ),
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
