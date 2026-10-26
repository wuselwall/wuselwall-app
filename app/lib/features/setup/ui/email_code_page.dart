import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/sign_in_choice.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';

/// E2 (specs/20, "With email"): six digit boxes over one hidden field. Paste and the
/// platform's one-time-code autofill fill the field; the sixth digit submits.
class EmailCodePage extends ConsumerStatefulWidget {
  const EmailCodePage({
    required this.email,
    this.initialResendDelay = const Duration(seconds: emailCodeResendSeconds),
    super.key,
  });

  /// The remaining delay after the send that opened this page. Passing zero
  /// also permits deterministic captures of the resend state.
  final Duration initialResendDelay;

  final String email;

  @override
  ConsumerState<EmailCodePage> createState() => _EmailCodePageState();
}

class _EmailCodePageState extends ConsumerState<EmailCodePage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _ticker;
  // Counts down from the send that opened this page (E1 sent the code).
  late int _secondsLeft;
  bool _busy = false;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _startCountdown(widget.initialResendDelay);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _startCountdown([
    Duration delay = const Duration(seconds: emailCodeResendSeconds),
  ]) {
    assert(!delay.isNegative);
    _ticker?.cancel();
    _secondsLeft = delay.inSeconds;
    if (_secondsLeft <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify(String digits) async {
    if (_busy || digits.length != emailCodeLength) return;
    setState(() {
      _busy = true;
      _wrong = false;
    });
    final result = await ref
        .read(identityRepositoryProvider)
        .verifyEmailCode(widget.email, digits);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      // Signed in. The router takes over; a new account owes E3 first.
      case Ok(value: final isNew):
        if (isNew) ref.read(signInChoiceOwedProvider.notifier).owe();
      case Err(failure: AuthFailure()):
        _code.clear();
        setState(() => _wrong = true);
        _focus.requestFocus();
      case Err(:final failure):
        _code.clear();
        context.showFailure(failure);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .sendEmailCode(
          widget.email,
          locale: Localizations.localeOf(context).languageCode,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        setState(_startCountdown);
        context.showMessage(context.l10n.emailCodeResent);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final waiting = _secondsLeft > 0;

    return AuthFormScaffold(
      title: l10n.emailCodeTitle,
      children: [
        Text(l10n.emailCodeSent(widget.email)),
        const SizedBox(height: Tokens.space6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _code,
          builder: (context, value, _) {
            final digits = value.text;
            final focusAt = _focus.hasFocus ? digits.length : -1;
            return Semantics(
              label: l10n.emailCodeFieldLabel,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < emailCodeLength; i++)
                        _DigitBox(
                          digit: i < digits.length ? digits[i] : '',
                          focused: i == focusAt,
                        ),
                    ],
                  ),
                  // The one real field: it takes typing, paste and autofill. The boxes
                  // only show it, and it sits above them so a tap lands in it.
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        key: const ValueKey('email-code-field'),
                        controller: _code,
                        focusNode: _focus,
                        autofocus: true,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        maxLength: emailCodeLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (text) {
                          if (text.length == emailCodeLength) _verify(text);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_wrong) ...[
          const SizedBox(height: Tokens.space4),
          Text(
            l10n.emailCodeWrong,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
        ],
        const SizedBox(height: Tokens.space6),
        if (waiting)
          TextButton(
            onPressed: null,
            child: Text(l10n.emailCodeResendIn(_secondsLeft)),
          )
        else ...[
          Text(l10n.emailCodeSpam, textAlign: TextAlign.center),
          TextButton(
            onPressed: _busy ? null : _resend,
            child: Text(l10n.emailCodeResend),
          ),
          TextButton(
            onPressed: () => context.go(Routes.setup),
            child: Text(l10n.emailCodeOtherMethod),
          ),
        ],
        TextButton(
          onPressed: () => context.go(emailSignInLocation(widget.email)),
          child: Text(l10n.emailCodeOtherAddress),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: Tokens.space4),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

/// E1 again, with the address filled in.
String emailSignInLocation(String email) =>
    '${Routes.signIn}?email=${Uri.encodeQueryComponent(email)}';

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit, required this.focused});

  final String digit;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: Tokens.space1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? scheme.primary : scheme.outline,
          width: focused ? 2 : 1,
        ),
      ),
      child: Text(digit, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
