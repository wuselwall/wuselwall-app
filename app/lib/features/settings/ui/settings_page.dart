import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/module_band.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_access.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/ui/own_settings_page.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';

/// Einstellungen: a short page of groups, each opening its own page (specs/21, "Where the
/// settings live"). A group with nothing to show on this device in this view has no tile.
/// Reading is open to the household; every change is a guardian action and goes through
/// `ensureGuardian` (PIN step-up on shared devices).
///
/// Basic shows what a family needs to get going; Advanced adds the rest. Hiding a row
/// changes nothing it controls.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A child, or an adult who is not a guardian, at a shared device: their own page only.
    if (ref.watch(settingsAccessProvider) == SettingsAccess.own) {
      return const OwnSettingsPage();
    }
    final l10n = context.l10n;
    final env = ref.watch(settingsEnvProvider);
    final thisDevice = ref.watch(deviceProvider).value;

    return PopScope<Object?>(
      // Settings can also be opened directly (for example from a deep link). In that
      // case the platform Back gesture has no home route to pop to.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          // Settings have their band too, the calm `stein` (specs/26).
          backgroundColor: context.ww.band(AppModule.settings),
          title: Text(l10n.settingsTitle),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.home);
              }
            },
          ),
          actions: [
            // The back button, and the Advanced chip at its widest language.
            if (ModuleIllustration.fits(
              context,
              title: l10n.settingsTitle,
              controls: kMinInteractiveDimension + 160,
            ))
              const ModuleIllustration(AppModule.settings),
            const SettingsViewSwitch(),
          ],
        ),
        body: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            children: [
              for (final group in visibleGroups(env))
                ListTile(
                  key: ValueKey('settings-group-${group.name}'),
                  leading: Icon(group.icon),
                  title: Text(group.title(l10n)),
                  subtitle: Text(group.subtitle(l10n, advanced: env.advanced)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(group.route),
                ),
              if (hasHiddenSettings(env)) const MoreSettingsHint(),
              const SizedBox(height: Tokens.space6),
              OutlinedButton.icon(
                onPressed: () => thisDevice?.deviceClass == DeviceClass.personal
                    ? ref.read(identityRepositoryProvider).signOutDevice()
                    : ref.read(identityRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: Text(l10n.signOutDevice),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
