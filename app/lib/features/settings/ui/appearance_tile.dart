import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// Light, dark or automatic for this device (#80). Not a guardian action: it changes
/// nothing for anyone else.
class AppearanceTile extends ConsumerWidget {
  const AppearanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(appearanceProvider).value ?? ThemeMode.system;
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(l10n.appearanceTitle),
      subtitle: Text(_label(l10n, mode)),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _AppearanceDialog(),
      ),
    );
  }
}

class _AppearanceDialog extends ConsumerWidget {
  const _AppearanceDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(appearanceProvider).value ?? ThemeMode.system;
    final kiosk =
        ref.watch(deviceProvider).value?.deviceClass == DeviceClass.kiosk;
    return AlertDialog(
      title: Text(l10n.appearanceTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: Tokens.space4),
      content: SingleChildScrollView(
        child: RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (value) {
            if (value == null) return;
            ref.read(appearanceProvider.notifier).select(value);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: Text(l10n.appearanceSystem),
                subtitle: Text(l10n.appearanceSystemHelp),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: Text(l10n.appearanceLight),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: Text(l10n.appearanceDark),
              ),
              if (kiosk)
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  subtitle: Text(l10n.appearanceNightNote),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

String _label(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.appearanceSystem,
  ThemeMode.light => l10n.appearanceLight,
  ThemeMode.dark => l10n.appearanceDark,
};
