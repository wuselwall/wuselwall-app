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

/// At the end of a Basic screen: more exists, and it still applies. One quiet line that
/// names the chip above; the chip is the one way to switch (specs/21, "Where the settings
/// live").
class MoreSettingsHint extends StatelessWidget {
  const MoreSettingsHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('settings-more-hint'),
      padding: const EdgeInsets.only(top: Tokens.space6),
      child: Text(
        context.l10n.settingsViewMoreHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
