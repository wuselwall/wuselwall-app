import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';

/// Shared frame for the pre-enrolment forms: back to setup, centred, scrollable.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    required this.title,
    required this.children,
    this.showBack = true,
    this.onBack,
    super.key,
  });

  final String title;
  final List<Widget> children;

  /// Off where going back would only bring the person straight back (E3).
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? BackButton(onPressed: onBack ?? () => context.go(Routes.setup))
          : null,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(Tokens.space6),
            children: children,
          ),
        ),
      ),
    ),
  );
}
