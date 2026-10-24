import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_compat.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';

/// Hilfe und Info → Erste Schritte: brings the setup card back and shows it on the Today
/// tab.
class GettingStartedTile extends ConsumerWidget {
  const GettingStartedTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.flag_outlined),
      title: Text(l10n.settingsGettingStarted),
      subtitle: Text(l10n.settingsGettingStartedSubtitle),
      onTap: () => _show(context, ref),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context);
    final repository = ref.read(gettingStartedRepositoryProvider);
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final actor = container.read(actingProfileProvider);
    if (actor == null) return;
    final result = await repository.restore(actor: actor);
    container
      ..invalidate(gettingStartedProvider)
      ..read(homeTabProvider.notifier).select(HomeTab.today);
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      context.showFailure(failure);
      return;
    }
    context.go(Routes.home);
  }
}

/// "App 1.1.0 · Server 0.3.0 · API 1": which pair runs here, the first thing support asks.
/// The app only runs on a server it fits (server_compat.dart), so the line needs no
/// verdict of its own.
class VersionsTile extends ConsumerWidget {
  const VersionsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final server = ref.watch(appConfigProvider).server;
    final app =
        ref.watch(appVersionProvider).value ?? l10n.settingsVersionUnknown;
    return ListTile(
      key: const ValueKey('settings-versions'),
      leading: const Icon(Icons.info_outline),
      title: Text(l10n.settingsVersions),
      subtitle: Text(
        l10n.settingsVersionsLine(
          app,
          server?.serverVersion ?? l10n.settingsVersionUnknown,
          (server?.apiVersion ?? appApiVersion).toString(),
        ),
      ),
    );
  }
}

class LicencesTile extends StatelessWidget {
  const LicencesTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.gavel_outlined),
      title: Text(l10n.settingsLicenses),
      subtitle: Text(l10n.settingsLicensesSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLicensePage(
        context: context,
        applicationName: 'WuselWall',
        applicationLegalese:
            'Copyright 2026 Daniel Huser and the WuselWall contributors.\n'
            'Licensed under the Apache License, Version 2.0.',
      ),
    );
  }
}
