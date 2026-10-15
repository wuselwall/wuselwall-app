import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';

/// The new device's side of J3 (P1): shows a code and a QR code, polls until a guardian's
/// phone approves it, signs in with the credentials that come back, and greets the household.
/// It never shows an error screen: a fresh code replaces an expired one, and a rate limit
/// means waiting.
class PairPage extends ConsumerStatefulWidget {
  const PairPage({super.key});

  @override
  ConsumerState<PairPage> createState() => _PairPageState();
}

class _PairPageState extends ConsumerState<PairPage> {
  static const _pollEvery = Duration(seconds: 2);

  /// Ten-minute lifetime, renewed 30 s before it runs out. Counted from receipt, so a device
  /// clock that is off does not make it renew in a loop.
  static const _renewAfter = Duration(minutes: 9, seconds: 30);
  static const _retryAfterFailure = Duration(seconds: 5);
  static const _waitWhenLimited = Duration(seconds: 30);
  static const _greeting = Duration(seconds: 2);

  PairingRequest? _request;
  String? _connected;
  Timer? _pollTimer;
  Timer? _renewTimer;
  bool _starting = false;
  bool _polling = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _renewTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _connecting) return;
    _starting = true;
    _pollTimer?.cancel();
    _renewTimer?.cancel();
    final result = await ref.read(pairingRepositoryProvider).start();
    _starting = false;
    if (!mounted || _connecting) return;
    switch (result) {
      case Ok(:final value):
        setState(() => _request = value);
        _pollTimer = Timer.periodic(_pollEvery, (_) => unawaited(_poll()));
        _renewTimer = Timer(_renewAfter, () => unawaited(_start()));
      case Err(:final failure):
        final wait = failure is PermissionFailure
            ? _waitWhenLimited
            : _retryAfterFailure;
        _renewTimer = Timer(wait, () => unawaited(_start()));
    }
  }

  Future<void> _poll() async {
    final request = _request;
    if (_polling || request == null || _connecting) return;
    _polling = true;
    final result = await ref.read(pairingRepositoryProvider).poll(request);
    _polling = false;
    if (!mounted || _request != request || _connecting) return;
    switch (result.valueOrNull) {
      case final PairingApproved approved:
        await _connect(approved);
      case PairingExpired() || PairingInvalid():
        unawaited(_start());
      case PairingPending() || PairingRateLimited() || null:
        break;
    }
  }

  Future<void> _connect(PairingApproved creds) async {
    _connecting = true;
    _pollTimer?.cancel();
    _renewTimer?.cancel();
    // Holds this page up for the greeting while the router sees the new session.
    ref.read(pairingHandoffProvider.notifier).hold(creds.householdName);
    final signIn = await ref
        .read(identityRepositoryProvider)
        .signIn(creds.email, creds.password);
    if (!mounted) return;
    if (signIn case Err(:final failure)) {
      ref.read(pairingHandoffProvider.notifier).release();
      context.showFailure(failure);
      _connecting = false;
      unawaited(_start());
      return;
    }
    setState(() => _connected = creds.householdName);
    await Future<void>.delayed(_greeting);
    if (!mounted) return;
    ref.read(pairingHandoffProvider.notifier).release();
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final request = _request;
    final household = _connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairTitle),
        leading: BackButton(onPressed: () => context.go(Routes.setup)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                if (household != null) ...[
                  Icon(Icons.check_circle, size: 64, color: context.ww.success),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    l10n.pairConnected(household),
                    key: const ValueKey('pair-connected'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ] else if (request == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Text(
                    l10n.pairScanHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Tokens.space4),
                  Center(
                    child: QrCodeView(
                      key: const ValueKey('pair-qr'),
                      data: pairingQrPayload(
                        request.code,
                        server: ref.watch(currentServerProvider),
                      ),
                      semanticsLabel: l10n.pairQrLabel,
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatPairingCode(request.code),
                      key: const ValueKey('pair-code'),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        letterSpacing: 6,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: Tokens.space3),
                  Text(
                    l10n.pairCodeHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: Tokens.space4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: Tokens.space2),
                      Text(l10n.pairWaiting),
                    ],
                  ),
                ],
                const SizedBox(height: Tokens.space6),
                TextButton(
                  onPressed: () => context.go(Routes.enrol),
                  child: Text(l10n.pairOldCodeLink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
