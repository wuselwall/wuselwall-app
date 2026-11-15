import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/ui/look_chooser.dart';

/// Light, dark or automatic for this device (#80), and its colour themes (#280). Not a
/// guardian action: it changes nothing for anyone else.
class AppearanceTile extends ConsumerWidget {
  const AppearanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(appearanceProvider).value ?? ThemeMode.system;
    final looks = ref.watch(looksProvider).value ?? const Looks();
    // The themes that can be on screen: both while the device decides, else the one.
    final themes = [
      if (mode != ThemeMode.dark) lookLabel(l10n, looks.light),
      if (mode != ThemeMode.light) lookLabel(l10n, looks.dark),
    ].join(', ');
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(l10n.appearanceTitle),
      subtitle: Text('${_label(l10n, mode)} · $themes'),
      onTap: () => showLookSheet(context),
    );
  }
}

String _label(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.appearanceSystem,
  ThemeMode.light => l10n.appearanceLight,
  ThemeMode.dark => l10n.appearanceDark,
};
