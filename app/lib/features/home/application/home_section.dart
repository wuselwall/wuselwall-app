import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// One destination of the adult home (specs/09 "Screens by register"): its tab, its app
/// bar title and toolbar, its body and its button. Each feature owns its section in its
/// own `ui/*_section.dart`, so the shell never changes when a feature does.
class HomeSection {
  const HomeSection({
    required this.icon,
    required this.label,
    this.navLabel,
    required this.body,
    this.bottom,
    this.appBar,
    this.fab,
  });

  final IconData icon;
  final String Function(AppLocalizations l10n) label;

  /// A shorter label for the navigation bar, where six destinations share a phone's width;
  /// the bar's tooltip keeps [label].
  final String Function(AppLocalizations l10n)? navLabel;
  final Widget body;
  final PreferredSizeWidget? bottom;

  /// A feature can combine its controls and the shared actions in one app bar.
  final PreferredSizeWidget Function(
    BuildContext context,
    List<Widget> actions,
  )?
  appBar;
  final Widget Function(BuildContext context)? fab;
}

/// Whether a section's app bar has room for the title next to its controls: 900 logical
/// pixels at the text scale in use.
bool homeBarIsWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width /
        MediaQuery.textScalerOf(context).scale(1) >=
    900;

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
