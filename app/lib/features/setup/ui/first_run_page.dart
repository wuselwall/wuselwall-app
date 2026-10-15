import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';

/// The one-time introduction of a newly connected shared device (J3): a checklist for a
/// wall display, the welcome for a kids' tablet. "Fertig" marks the device as having seen it.
class FirstRunPage extends ConsumerStatefulWidget {
  const FirstRunPage({required this.kind, super.key});

  final FirstRun kind;

  @override
  ConsumerState<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends ConsumerState<FirstRunPage> {
  bool _busy = false;

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final device = ref.read(deviceProvider).value;
    if (device != null) {
      await ref.read(firstRunStoreProvider).markSeen(device.deviceId);
    }
    ref.invalidate(pendingFirstRunProvider);
    await ref.read(pendingFirstRunProvider.future);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;

    final children = switch (widget.kind) {
      FirstRun.kiosk => [
        Text(l10n.firstRunKioskBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Tokens.space4),
        _Step(
          icon: Icons.push_pin_outlined,
          title: l10n.firstRunPinTitle,
          body: ios ? l10n.firstRunPinIos : l10n.firstRunPinAndroid,
        ),
        _Step(
          icon: Icons.visibility_outlined,
          title: l10n.firstRunAwakeTitle,
          body: ios ? l10n.firstRunAwakeIos : l10n.firstRunAwakeAndroid,
        ),
        _Step(
          icon: Icons.power_outlined,
          title: l10n.firstRunPowerTitle,
          body: l10n.firstRunPowerBody,
        ),
      ],
      FirstRun.kidWelcome => [
        Icon(Icons.face_outlined, size: 96, color: theme.colorScheme.primary),
        const SizedBox(height: Tokens.space4),
        Text(
          l10n.firstRunKidBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
      ],
    };

    final action = switch (widget.kind) {
      FirstRun.kiosk => l10n.firstRunDone,
      FirstRun.kidWelcome => l10n.firstRunKidStart,
    };
    final headline = switch (widget.kind) {
      FirstRun.kiosk => l10n.firstRunKioskTitle,
      FirstRun.kidWelcome => l10n.firstRunKidTitle,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Tokens.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(headline, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: Tokens.space4),
                  ...children,
                  const SizedBox(height: Tokens.space6),
                  FilledButton(
                    key: const ValueKey('first-run-done'),
                    onPressed: _busy ? null : _finish,
                    child: Text(action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: Tokens.space1),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
