import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';

/// Creates the household and its first guardian. Guarded server-side by the one-time
/// setup token and closed for good once a household exists. The other members are added
/// afterwards in Settings; TOTP for the guardian is a later step.
class WizardPage extends ConsumerStatefulWidget {
  const WizardPage({super.key});

  @override
  ConsumerState<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends ConsumerState<WizardPage> {
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _household = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_token, _household, _name, _email, _password, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .setupHousehold(
          token: _token.text,
          householdName: _household.text,
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
          pin: _pin.text,
          // The first member gets the first swatch; the picker comes with M0.1.
          colorHex: toHex(MemberPalette.swatches.first.light),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.failureOrNull.let(context.showFailure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null;

    Widget field(
      TextEditingController c,
      String label, {
      bool obscure = false,
      TextInputType? type,
      String? Function(String?)? validator,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space4),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
        validator: validator ?? required,
      ),
    );

    return AuthFormScaffold(
      title: l10n.wizardTitle,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field(_token, l10n.fieldSetupToken),
              field(_household, l10n.fieldHouseholdName),
              field(_name, l10n.fieldYourName),
              field(_email, l10n.fieldEmail, type: TextInputType.emailAddress),
              field(
                _password,
                l10n.fieldPassword,
                obscure: true,
                validator: (v) =>
                    (v ?? '').length < 10 ? l10n.errPasswordTooShort : null,
              ),
              field(
                _pin,
                l10n.fieldPin,
                obscure: true,
                type: TextInputType.number,
                validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                    ? null
                    : l10n.errPinFormat,
              ),
              const SizedBox(height: Tokens.space2),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(l10n.wizardCreate),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
