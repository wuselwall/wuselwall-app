import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// One destination of the adult home (specs/09 "Screens by register"): its tab, its app
/// bar title and toolbar, its body and its button. Each feature owns its section in its
/// own `ui/*_section.dart`, so the shell never changes when a feature does.
class HomeSection {
  const HomeSection({
    required this.icon,
    required this.label,
    required this.body,
    this.bottom,
    this.fab,
  });

  final IconData icon;
  final String Function(AppLocalizations l10n) label;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final Widget Function(BuildContext context)? fab;
}

/// A section whose feature is still being built: says so instead of showing nothing.
class ComingSoonBody extends StatelessWidget {
  const ComingSoonBody({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(context.l10n.comingSoon, textAlign: TextAlign.center),
    ),
  );
}
