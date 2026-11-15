import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';

/// A settings row with its own action button (Passwort ändern, Einschalten, Sperren).
/// Beside the text where there is room; under it on a phone, so the title and the
/// explanation keep the row's width instead of a narrow column beside the button
/// ("PIN für Erziehungsb / erechtigte", specs/21 "Where the settings live").
class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    required this.leading,
    required this.title,
    required this.action,
    this.subtitle,
    this.onTap,
    super.key,
  });

  /// Below this width the action moves under the text.
  static const stackBelow = 480.0;

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? action;
  final VoidCallback? onTap;

  // ListTile's own measures, spelled out so that the action under the text can start where
  // the title starts: the row's padding, the leading box and the gap after it.
  static const _padding = Tokens.space4;
  static const _leadingWidth = 40.0;
  static const _gap = Tokens.space4;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final action = this.action;
      final tile = ListTile(
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: _padding,
        ),
        minLeadingWidth: _leadingWidth,
        horizontalTitleGap: _gap,
        leading: leading,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      );
      if (action == null) return tile;
      // The button stands beside or under the row, never in it: a row that can be tapped
      // is a button to a screen reader, and a button inside a button cannot be reached.
      if (constraints.maxWidth >= stackBelow) {
        return Row(
          children: [
            Expanded(child: tile),
            action,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tile,
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _padding + _leadingWidth + _gap,
              bottom: Tokens.space2,
            ),
            child: action,
          ),
        ],
      );
    },
  );
}
