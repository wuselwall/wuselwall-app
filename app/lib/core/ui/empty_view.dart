import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';

/// What a screen shows when it has nothing to show: always centred in the space it is
/// given, with buttons that lead to the first entry where adding one makes sense. In
/// bounded space it scrolls, so a surrounding [RefreshIndicator] still pulls.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.title,
    this.actions = const [],
    this.scrolls = true,
    super.key,
  });

  final String message;
  final String? title;

  /// The call to action, the most likely first: usually a [FilledButton], then an
  /// [OutlinedButton] for the alternative.
  final List<Widget> actions;

  /// False where the parent scrolls already, such as a `SliverFillRemaining`, which
  /// measures its child and so cannot hold a [LayoutBuilder].
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(Tokens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title case final title?) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Tokens.space2),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: title == null ? null : TextStyle(color: context.ww.ink2),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Tokens.space4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: actions,
            ),
          ],
        ],
      ),
    );
    if (!scrolls) return Center(child: content);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
