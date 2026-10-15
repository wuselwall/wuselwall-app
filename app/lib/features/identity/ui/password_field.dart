import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';

/// A new password with the strength indicator under it (specs/20, E3 and Settings).
class PasswordField extends StatelessWidget {
  const PasswordField({
    required this.controller,
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: autofocus,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: context.l10n.fieldPassword,
              ),
              onSubmitted: onSubmitted,
            ),
            if (value.text.isNotEmpty) ...[
              const SizedBox(height: Tokens.space2),
              PasswordStrengthMeter(strength: ratePassword(value.text)),
            ],
          ],
        ),
      );
}

/// Four states, one bar: too short, weak, fair, strong. Colours from the theme only.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.strength, super.key});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (fraction, colour, label) = switch (strength) {
      PasswordStrength.tooShort => (
        0.15,
        scheme.error,
        l10n.passwordStrengthShort,
      ),
      PasswordStrength.weak => (0.35, scheme.error, l10n.passwordStrengthWeak),
      PasswordStrength.fair => (
        0.65,
        scheme.tertiary,
        l10n.passwordStrengthFair,
      ),
      PasswordStrength.strong => (
        1.0,
        scheme.primary,
        l10n.passwordStrengthStrong,
      ),
    };
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: fraction, color: colour),
          const SizedBox(height: Tokens.space1),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}
