import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';
import 'package:wuselwall/features/setup/ui/busy_button_label.dart';
import 'package:wuselwall/features/setup/ui/email_code_page.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';

/// S1 "Server einrichten" (specs/20, "Claiming the server"): the first screen after a
/// setup link, and the way in on a server that has no family yet. The setup key is
/// checked with the server at once; the address typed here is announced with it, so
/// the server lets exactly this address sign up, and "Neue Familie" asks for no key.
class ClaimPage extends ConsumerStatefulWidget {
  const ClaimPage({this.initialEmail, super.key});

  /// Prefilled when E2 sends the person back to change the address.
  final String? initialEmail;

  @override
  ConsumerState<ClaimPage> createState() => _ClaimPageState();
}

enum _KeyState { checking, ready, used, invalid, rateLimited, unreachable }

class _ClaimPageState extends ConsumerState<ClaimPage> {
  final _form = GlobalKey<FormState>();
  final _key = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  String? _storedKey;
  _KeyState? _keyState;
  var _loading = true;
  var _busy = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _key.dispose();
    _email.dispose();
    super.dispose();
  }

  Uri? get _server => ref.read(currentServerProvider);

  /// The key the setup link left on this device, checked with the server right away.
  Future<void> _load() async {
    final server = _server;
    final stored = server == null
        ? null
        : await ref.read(setupStoreProvider).read(server);
    if (!mounted) return;
    setState(() {
      _storedKey = stored;
      _loading = false;
    });
    if (stored != null) await _check(stored);
  }

  Future<void> _check(String key) async {
    setState(() => _keyState = _KeyState.checking);
    final result = await ref
        .read(householdOnboardingRepositoryProvider)
        .claim(key: key);
    if (!mounted) return;
    setState(() => _keyState = _stateOf(result));
  }

  _KeyState _stateOf(Result<ClaimOutcome> result) => switch (result) {
    Ok(value: ClaimAccepted()) => _KeyState.ready,
    Ok(value: ClaimRefused(reason: 'key_used')) => _KeyState.used,
    Ok(value: ClaimRefused(reason: 'rate_limited')) => _KeyState.rateLimited,
    Ok(value: ClaimRefused()) => _KeyState.invalid,
    Err() => _KeyState.unreachable,
  };

  /// A stored key that the server refused is no key: the field opens for another one.
  bool get _typesKey =>
      _storedKey == null ||
      _keyState == _KeyState.used ||
      _keyState == _KeyState.invalid;

  Future<void> _continue() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final key = _typesKey ? _key.text.trim() : _storedKey!;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _emailError = null;
    });
    final repo = ref.read(householdOnboardingRepositoryProvider);
    final claimed = await repo.claim(key: key, email: email);
    if (!mounted) return;
    switch (claimed) {
      case Ok(value: ClaimAccepted()):
        break;
      case Ok(value: ClaimRefused(reason: 'email_invalid')):
        setState(() {
          _busy = false;
          _emailError = context.l10n.emailInvalid;
        });
        return;
      case Ok(value: ClaimRefused(reason: 'rate_limited')):
        setState(() => _busy = false);
        context.showMessage(context.l10n.householdNewErrRateLimited);
        return;
      case Ok():
        setState(() {
          _busy = false;
          _keyState = _stateOf(claimed);
        });
        return;
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
        return;
    }
    // The address is announced: now the account, as on E1. On a server with mail the
    // code goes out at once; without mail the password page opens on "Neues Konto".
    if (!ref.read(emailCodeSignInProvider)) {
      setState(() => _busy = false);
      context.go(emailSignInLocation(email));
      return;
    }
    final sent = await ref
        .read(identityRepositoryProvider)
        .sendEmailCode(
          email,
          locale: Localizations.localeOf(context).languageCode,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (sent) {
      case Ok():
        unawaited(context.push(emailCodeLocation(email)));
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  /// Not founding after all: the front door, with the key kept on the device for later.
  void _leave(String route) {
    ref.read(serverSessionProvider).setupPending.value = false;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final online = ref.watch(connectivityProvider).value ?? true;
    final server = ref.watch(currentServerProvider);
    final host = server == null ? '' : displayServerAddress(server);
    final checking = _loading || _keyState == _KeyState.checking;
    final blocked =
        _busy ||
        checking ||
        !online ||
        _keyState == _KeyState.rateLimited ||
        _keyState == _KeyState.unreachable;

    return AuthFormScaffold(
      title: l10n.claimTitle,
      onBack: () => _leave(Routes.setup),
      children: [
        Text(l10n.claimLead(host)),
        const SizedBox(height: Tokens.space4),
        if (!online) ...[
          Container(
            padding: const EdgeInsets.all(Tokens.space3),
            color: ww.warningContainer,
            child: Text(
              l10n.emailOffline,
              style: TextStyle(color: ww.onWarningContainer),
            ),
          ),
          const SizedBox(height: Tokens.space4),
        ],
        if (_storedKey != null && _keyState != null) ...[
          _KeyStatus(state: _keyState!),
          const SizedBox(height: Tokens.space4),
        ],
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loading && _typesKey) ...[
                TextFormField(
                  key: const ValueKey('claim-key'),
                  controller: _key,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.claimKeyLabel,
                    helperText: l10n.claimKeyHelp,
                    helperMaxLines: 3,
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? l10n.fieldRequired
                      : null,
                ),
                const SizedBox(height: Tokens.space4),
              ],
              TextFormField(
                key: const ValueKey('claim-email'),
                controller: _email,
                enabled: !_busy,
                autofocus: _storedKey != null,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.fieldEmail,
                  errorText: _emailError,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return l10n.emailRequired;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return l10n.emailInvalid;
                  }
                  return null;
                },
                onFieldSubmitted: (_) => blocked ? null : _continue(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space3),
        Text(
          ref.watch(emailCodeSignInProvider)
              ? l10n.claimNextCode
              : l10n.claimNextPassword,
          style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
        ),
        const SizedBox(height: Tokens.space6),
        FilledButton(
          key: const ValueKey('claim-continue'),
          onPressed: blocked ? null : _continue,
          child: _busy
              ? BusyButtonLabel(label: l10n.emailSendingCode)
              : Text(l10n.emailContinue),
        ),
        TextButton(
          onPressed: _busy ? null : () => _leave(Routes.signIn),
          child: Text(l10n.claimHaveAccount),
        ),
      ],
    );
  }
}

/// What the server said about the key the setup link brought.
class _KeyStatus extends StatelessWidget {
  const _KeyStatus({required this.state});

  final _KeyState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, colour) = switch (state) {
      _KeyState.checking => (
        Icons.hourglass_top,
        l10n.claimChecking,
        scheme.onSurfaceVariant,
      ),
      _KeyState.ready => (
        Icons.check_circle_outline,
        l10n.claimKeyReady,
        scheme.primary,
      ),
      _KeyState.used => (Icons.error_outline, l10n.claimKeyUsed, scheme.error),
      _KeyState.invalid => (
        Icons.error_outline,
        l10n.claimKeyInvalid,
        scheme.error,
      ),
      _KeyState.rateLimited => (
        Icons.error_outline,
        l10n.householdNewErrRateLimited,
        scheme.error,
      ),
      _KeyState.unreachable => (
        Icons.wifi_off,
        l10n.serverUnreachable,
        scheme.error,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text(text, style: TextStyle(color: colour)),
          ),
        ],
      ),
    );
  }
}

/// Where E2 sends the person to change the address while the server is being set up.
String claimLocation(String email) =>
    '${Routes.claim}?email=${Uri.encodeQueryComponent(email)}';
