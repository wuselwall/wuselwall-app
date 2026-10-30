import 'package:flutter/widgets.dart';

/// The widest an adult page's reading content gets (specs/09 "Screens by register"):
/// lists and cards stop here on a laptop instead of running edge to edge, where a title
/// sits far left and its "in 3 Tagen" far right.
const adultMaxContentWidth = 960.0;

/// Centres [child] at most [maxWidth] wide; narrower screens get it unchanged. The
/// height stays the parent's, so a scrolling page keeps its full height. Grids that use
/// the width (the calendar, the meal week) are not wrapped.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    required this.child,
    this.maxWidth = adultMaxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final spare = box.maxWidth - maxWidth;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: spare > 0 ? spare / 2 : 0),
        child: child,
      );
    },
  );
}
