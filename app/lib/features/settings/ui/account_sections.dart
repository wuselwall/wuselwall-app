import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/set_password_dialog.dart';

/// How this account signs in (specs/20, "Several ways into one account") — for the
/// adult's own phone: the email code, always, and an optional password. On a server
/// without mail, the password only (Q48).
class SignInMethodsSection extends ConsumerStatefulWidget {
  const SignInMethodsSection({super.key});

  @override
  ConsumerState<SignInMethodsSection> createState() =>
      _SignInMethodsSectionState();
}

class _SignInMethodsSectionState extends ConsumerState<SignInMethodsSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = ref.watch(myAccountProvider).value?.email;
    final hasPassword = ref.read(identityRepositoryProvider).hasPassword();
    // A server without mail has no email code: the password is the way in (Q48).
    final emailCode = ref.watch(emailCodeSignInProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (emailCode)
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(l10n.signInMethodEmail),
            // The e-mail code is always there for an account with an address.
            subtitle: Text(
              email == null
                  ? l10n.signInMethodAlwaysAvailable
                  : l10n.signInMethodEmailSubtitle(email),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.settingsPasswordTitle),
          subtitle: Text(
            !emailCode
                ? l10n.settingsPasswordNoMail
                : hasPassword
                ? l10n.settingsPasswordSet
                : l10n.settingsPasswordNotSet,
          ),
          trailing: OutlinedButton(
            onPressed: _setPassword,
            child: Text(
              hasPassword ? l10n.passwordChangeAction : l10n.passwordSetAction,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setPassword() async {
    final saved = await showSetPasswordDialog(context);
    if (!saved || !mounted) return;
    setState(() {});
    context.showMessage(context.l10n.passwordSaved);
  }
}

/// Second factor and passkeys — for the guardian's own phone.
class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final factor = ref.watch(totpFactorProvider);
    final repo = ref.read(identityRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        factor.when(
          loading: () => const ListTile(title: LinearProgressIndicator()),
          error: (_, _) => ListTile(title: Text(l10n.errorUnknown)),
          data: (id) => ListTile(
            leading: const Icon(Icons.security),
            title: Text(l10n.totpTitle),
            subtitle: Text(id == null ? l10n.totpOff : l10n.totpOn),
            trailing: id == null
                ? FilledButton(
                    onPressed: () => _enableTotp(context, ref),
                    child: Text(l10n.totpEnable),
                  )
                : TextButton(
                    onPressed: () async {
                      final result = await repo.totpDisable(id);
                      if (!context.mounted) return;
                      result.when(
                        ok: (_) => ref.invalidate(totpFactorProvider),
                        err: context.showFailure,
                      );
                    },
                    child: Text(l10n.totpDisable),
                  ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: Text(l10n.pinChangeTitle),
          subtitle: Text(l10n.pinChangeBody),
          trailing: OutlinedButton(
            onPressed: () => _changePin(context, repo),
            child: Text(l10n.pinChangeAction),
          ),
        ),
        // Not on the web until the passkeys SDK is self-hosted (web/index.html), and
        // only in a build that names its own server (ADR-018).
        if (!kIsWeb && ref.watch(appConfigProvider).passkeys)
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(l10n.passkeyTitle),
            subtitle: Text(l10n.passkeyBody),
            trailing: OutlinedButton(
              onPressed: () async {
                final result = await repo.registerPasskey(l10n.appTitle);
                if (!context.mounted) return;
                result.when(
                  ok: (_) => context.showMessage(l10n.passkeyAdded),
                  err: context.showFailure,
                );
              },
              child: Text(l10n.passkeyAdd),
            ),
          ),
      ],
    );
  }

  Future<void> _changePin(BuildContext context, IdentityRepository repo) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pinChangeTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l10n.pinChangeField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.pinChangeAction),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || !context.mounted) return;
    final result = await repo.setPin(pin: pin);
    if (!context.mounted) return;
    result.when(
      ok: (_) => context.showMessage(l10n.pinChanged),
      err: context.showFailure,
    );
  }

  Future<void> _enableTotp(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(identityRepositoryProvider);
    final enrolment = await repo.totpEnrol();
    if (!context.mounted) return;
    switch (enrolment) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok(:final value):
        final done = await showDialog<bool>(
          context: context,
          builder: (_) => _TotpEnrolDialog(enrolment: value),
        );
        if (done ?? false) ref.invalidate(totpFactorProvider);
    }
  }
}

class _TotpEnrolDialog extends ConsumerStatefulWidget {
  const _TotpEnrolDialog({required this.enrolment});

  final TotpEnrolment enrolment;

  @override
  ConsumerState<_TotpEnrolDialog> createState() => _TotpEnrolDialogState();
}

class _TotpEnrolDialogState extends ConsumerState<_TotpEnrolDialog> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .totpVerify(widget.enrolment.factorId, _code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => Navigator.pop(context, true),
      err: context.showFailure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.totpTitle),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.totpScanBody),
              const SizedBox(height: Tokens.space3),
              QrCodeView(
                data: widget.enrolment.uri,
                semanticsLabel: l10n.totpQrLabel,
              ),
              const SizedBox(height: Tokens.space3),
              SelectableText(
                widget.enrolment.secret,
                style: const TextStyle(letterSpacing: 2),
              ),
              const SizedBox(height: Tokens.space3),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(labelText: l10n.mfaCodeLabel),
                onSubmitted: (_) => _verify(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(l10n.mfaVerify),
        ),
      ],
    );
  }
}
