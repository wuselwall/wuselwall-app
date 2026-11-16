import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';

/// The width from which the option cards stand in a row instead of scrolling sideways
/// (specs/30 "Comparing and combining").
const tripWideLayout = 840.0;

/// A strip of cards that belong side by side: on a phone they scroll sideways, the first
/// and the next one peeking so it is obvious; from [tripWideLayout] they wrap in rows.
/// Cards in a scrolling strip are as tall as the tallest, so their rows line up.
class TripCardStrip extends StatelessWidget {
  const TripCardStrip({required this.label, required this.children, super.key});

  /// What a screen reader says for the strip.
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= tripWideLayout;
    final cardWidth = wide ? 300.0 : (width * 0.76).clamp(260.0, 300.0);
    final cards = [
      for (final c in children) SizedBox(width: cardWidth, child: c),
    ];
    return Semantics(
      container: true,
      label: label,
      child: wide
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Wrap(
                spacing: Tokens.space3,
                runSpacing: Tokens.space3,
                children: cards,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: Tokens.space3),
                      cards[i],
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// The frame of an option or a combination card; [highlighted] draws the ticked state.
class TripCardFrame extends StatelessWidget {
  const TripCardFrame({
    required this.child,
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.space3),
        side: BorderSide(
          color: highlighted ? scheme.primary : context.ww.line,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// One row of a card: a small icon and a text that wraps. An empty row says "–", so the
/// rows of neighbouring cards stay at the same height.
class TripCardRow extends StatelessWidget {
  const TripCardRow({
    required this.icon,
    required this.text,
    this.color,
    super.key,
  });

  final IconData icon;

  /// Null for a row this card has nothing for.
  final String? text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final muted = context.ww.ink3;
    final tint = text == null ? muted : color;
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: tint ?? context.ww.ink2),
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: text == null
                ? ExcludeSemantics(
                    child: Text('–', style: TextStyle(color: muted)),
                  )
                : Text(text!, style: TextStyle(color: tint)),
          ),
        ],
      ),
    );
  }
}

/// A small label on a card: the state, "cheapest".
class TripCardTag extends StatelessWidget {
  const TripCardTag({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(Tokens.space2),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space2,
        vertical: Tokens.space1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: Tokens.space1),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Keeps a row of tags at the same height whether or not it has any.
class TripCardTags extends StatelessWidget {
  const TripCardTags({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 28),
    child: Wrap(
      spacing: Tokens.space2,
      runSpacing: Tokens.space1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}
