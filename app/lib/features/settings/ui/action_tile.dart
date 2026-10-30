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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final action = this.action;
      final stacked = action != null && constraints.maxWidth < stackBelow;
      if (!stacked) {
        return ListTile(
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: action,
          onTap: onTap,
        );
      }
      return ListTile(
        leading: leading,
        title: title,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?subtitle,
            const SizedBox(height: Tokens.space2),
            action,
          ],
        ),
        onTap: onTap,
      );
    },
  );
}
