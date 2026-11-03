import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/features/setup/ui/server_caption.dart';

/// Shared frame for the pre-enrolment forms: back to setup, centred, scrollable.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.showServer = false,
    super.key,
  });

  final String title;

  /// A quiet line under the title: which server is being set up (specs/20 S1).
  final String? subtitle;
  final List<Widget> children;

  /// Off where going back would only bring the person straight back (E3).
  final bool showBack;
  final VoidCallback? onBack;

  /// For a page that takes a code, a password or the setup key: without a [subtitle],
  /// the quiet line names the server instead ([ServerCaption]).
  final bool showServer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: subtitle == null && !(showServer && !kIsWeb)
          ? Text(title)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const ServerCaption(),
              ],
            ),
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
