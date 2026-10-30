import 'package:flutter/material.dart';

/// The title of a settings page's app bar, which shares the bar with the Advanced chip.
/// [title] when it fits on one line, otherwise [shortTitle] ("Aufgaben" for "Aufgaben &
/// Belohnungen") rather than a title cut mid-word (specs/21, "Where the settings live").
/// [subtitle] is a second, smaller line, such as the person a page belongs to.
class SettingsBarTitle extends StatelessWidget {
  const SettingsBarTitle({
    required this.title,
    this.shortTitle,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? shortTitle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = shortTitle;
        final text =
            short != null &&
                short != title &&
                !_fits(context, title, constraints.maxWidth)
            ? short
            : title;
        final line = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
        final subtitle = this.subtitle;
        if (subtitle == null) return line;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line,
            Text(
              subtitle,
              key: const ValueKey('settings-bar-subtitle'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Whether [text] fits [maxWidth] on one line in the bar's title style.
  static bool _fits(BuildContext context, String text, double maxWidth) {
    if (!maxWidth.isFinite) return true;
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    return fits;
  }
}
