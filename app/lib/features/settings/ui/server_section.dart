import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';

/// The server this app talks to (ADR-018): its address and QR code, so another device
/// joins it with one scan, and the way to another server. Only for a store build, which
/// chose its server; a development build names its own.
class ServerSection extends ConsumerWidget {
  const ServerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(serverSessionProvider);
    if (config.server == null) return const SizedBox.shrink();
    final server = Uri.parse(config.supabaseUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: SelectableText(displayServerAddress(server)),
          subtitle: Text(l10n.settingsServerBody(displayServerAddress(server))),
        ),
        Center(
          child: QrCodeView(
            key: const ValueKey('server-qr'),
            data: serverQrPayload(server),
            semanticsLabel: l10n.settingsServer,
          ),
        ),
        if (session.leave != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _switch(context, ref, session),
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.settingsServerSwitch),
            ),
          ),
      ],
    );
  }

  /// Leaving a server empties the device: its outbox belongs to that server's household.
  /// A guardian decision, so a child cannot move the family tablet elsewhere.
  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    ServerSession session,
  ) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsServerSwitch),
        content: Text(l10n.settingsServerSwitchConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsServerSwitch),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final identity = ref.read(identityRepositoryProvider);
    final personal =
        ref.read(deviceProvider).value?.deviceClass == DeviceClass.personal;
    await ref.read(shoppingStoreProvider).clear();
    // Like "Sign out": a personal phone also gives up its device record.
    await (personal ? identity.signOutDevice() : identity.signOut());
    await session.leave?.call();
  }
}
