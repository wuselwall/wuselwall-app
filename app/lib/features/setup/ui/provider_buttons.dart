import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/sign_in_method.dart';

/// "Continue with Apple" / "Continue with Google", in each company's own colours
/// and mark (specs/20, "The front door"). Serves sign-up and sign-in alike.
class ProviderButton extends StatelessWidget {
  const ProviderButton({
    required this.provider,
    required this.onPressed,
    super.key,
  });

  final SignInProvider provider;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = switch (provider) {
      SignInProvider.apple => context.ww.appleButton,
      SignInProvider.google => context.ww.googleButton,
    };
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        side: BorderSide(color: colors.border),
      ),
      onPressed: onPressed,
      icon: switch (provider) {
        SignInProvider.apple => const Icon(Icons.apple, size: 22),
        SignInProvider.google => Image.asset(
          'assets/sign_in/google_g.png',
          width: 20,
          height: 20,
        ),
      },
      label: Text(switch (provider) {
        SignInProvider.apple => l10n.doorApple,
        SignInProvider.google => l10n.doorGoogle,
      }),
    );
  }
}
