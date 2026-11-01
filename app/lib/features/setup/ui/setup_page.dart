import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/legal/legal_links.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';

/// What every un-enrolled device shows (specs/20, "The front door"): sign-in with
/// email and an invitation, then below "or" the device code and a new household.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  @override
  void initState() {
    super.initState();
    // A device code came with the server (one scan at the server choice): straight on.
    if (ref.read(serverSessionProvider).hasPendingEnrolCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.enrol);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final online = ref.watch(connectivityProvider).value ?? true;
    final session = ref.watch(serverSessionProvider);
    // A server without a family (specs/20 "Claiming the server"): the way in is the
    // setup key, and the server refuses every other sign-up.
    final unclaimed = ref.watch(serverUnclaimedProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Tokens.space4),
                Text(l10n.setupHeadline, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Tokens.space2),
                Text(l10n.doorTagline),
                if (!online) ...[
                  const SizedBox(height: Tokens.space4),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(Tokens.space3),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Tokens.space3),
                          Expanded(child: Text(l10n.setupOfflineWelcome)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Tokens.space6),
                if (unclaimed) ...[
                  Container(
                    padding: const EdgeInsets.all(Tokens.space4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.doorUnclaimedTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: Tokens.space2),
                        Text(
                          l10n.doorUnclaimedBody,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: Tokens.space3),
                        FilledButton.icon(
                          key: const ValueKey('door-claim'),
                          onPressed: !online
                              ? null
                              : () => context.go(Routes.claim),
                          icon: const Icon(Icons.key_outlined),
                          label: Text(l10n.doorUnclaimedAction),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                ],
                // One primary action, then the other ways in as equal rows (specs/20,
                // "The front door").
                // E1: the address, then a code by e-mail (E2, E3).
                FilledButton.icon(
                  key: const ValueKey('door-email'),
                  onPressed: !online ? null : () => context.go(Routes.signIn),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(l10n.doorEmail),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.space3,
                        ),
                        child: Text(l10n.doorOr),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                // Pairing (J3): the new device shows a code, a guardian's phone approves it.
                _DoorOption(
                  key: const ValueKey('door-pair'),
                  icon: Icons.tablet_android,
                  label: l10n.pairFrontDoorAction,
                  onTap: !online ? null : () => context.go(Routes.pair),
                ),
                // An invitation: the code, a link or its QR code (J2).
                _DoorOption(
                  key: const ValueKey('door-invite'),
                  icon: Icons.mark_email_unread_outlined,
                  label: l10n.inviteDoorAction,
                  onTap: !online ? null : () => context.go(Routes.inviteCode),
                ),
                // The web app of a server: the phone joins the same server by scanning.
                if (kIsWeb) const _ContinueOnPhone(),
                const SizedBox(height: Tokens.space4),
                if (session.leave != null)
                  TextButton(
                    onPressed: session.leave,
                    child: Text(l10n.serverChooseOther),
                  ),
                // The privacy policy, quiet at the foot of the front door (specs/20).
                Center(
                  child: TextButton(
                    onPressed: online
                        ? () =>
                              openPrivacyPolicy(Localizations.localeOf(context))
                        : null,
                    child: Text(l10n.setupPrivacy),
                  ),
                ),
                if (kDebugMode)
                  TextButton(
                    onPressed: () => context.go(Routes.system),
                    child: Text(l10n.systemTitle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The server's QR code on the web front door: the phone app scans it and lands on the
/// same server (ADR-018, decision 3).
class _ContinueOnPhone extends ConsumerWidget {
  const _ContinueOnPhone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final server = Uri.parse(ref.watch(appConfigProvider).supabaseUrl);
    // The same row as the other options, opening in place instead of leading away.
    return ExpansionTile(
      key: const ValueKey('door-phone'),
      leading: const Icon(Icons.smartphone),
      title: Text(l10n.setupPhoneTitle, style: _DoorOption.labelStyle(context)),
      tilePadding: _DoorOption.padding,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.only(bottom: Tokens.space4),
      children: [
        Text(l10n.setupPhoneBody),
        const SizedBox(height: Tokens.space3),
        FutureBuilder<String?>(
          future: ref.read(setupStoreProvider).read(server),
          builder: (context, snapshot) => QrCodeView(
            data: serverQrPayload(
              server,
              setupToken: snapshot.data,
              webOrigin: kIsWeb ? Uri.parse(Uri.base.origin) : server,
            ),
            semanticsLabel: l10n.setupPhoneTitle,
          ),
        ),
        const SizedBox(height: Tokens.space2),
        SelectableText(displayServerAddress(server)),
      ],
    );
  }
}

/// One of the other ways in on the front door: an icon, the label (wrapping between
/// words where it must) and a chevron, all alike.
class _DoorOption extends StatelessWidget {
  const _DoorOption({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  static const padding = EdgeInsets.symmetric(horizontal: Tokens.space2);

  static TextStyle? labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: padding,
    leading: Icon(icon),
    title: Text(label, style: labelStyle(context)),
    trailing: const Icon(Icons.chevron_right),
    enabled: onTap != null,
    onTap: onTap,
  );
}
