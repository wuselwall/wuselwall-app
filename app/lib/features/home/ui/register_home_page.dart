import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

/// Home for every register. For now it is the shopping list; the week board, tasks and
/// calendar slot in beside it. Register-specific chrome lives here: the kiosk has no app
/// bar, reverts to nobody after 60 s idle, and nothing in it is smaller than 24 px.
class RegisterHomePage extends StatelessWidget {
  const RegisterHomePage({required this.register, super.key});

  final UiRegister register;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isKiosk = register == UiRegister.kiosk;

    final settings = IconButton(
      tooltip: l10n.settingsTitle,
      icon: const Icon(Icons.settings),
      onPressed: () => context.go(Routes.settings),
    );

    final page = Scaffold(
      appBar: isKiosk
          ? null
          : AppBar(
              title: Text(l10n.shoppingTitle),
              actions: [
                if (kDebugMode)
                  IconButton(
                    tooltip: l10n.systemTitle,
                    icon: const Icon(Icons.developer_mode),
                    onPressed: () => context.go(Routes.system),
                  ),
                settings,
              ],
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (isKiosk)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.space6,
                  Tokens.space2,
                  Tokens.space2,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.shoppingTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    settings,
                  ],
                ),
              ),
            const Expanded(child: ShoppingBody()),
            const ActingProfileBar(),
          ],
        ),
      ),
    );

    return isKiosk ? IdleReverter(child: page) : page;
  }
}
