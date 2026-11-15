import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How much of a cut row stays in sight: the 44 px a finger still hits (Apple's
/// minimum target). A catalogue tile shows its picture in that much.
const double kRowPeek = 44;

/// Rows of [children] (a [Wrap]) that scroll down, at most [maxHeight] tall, whose
/// bottom edge cuts a row on purpose: the cut row shows [peek] of itself, so it reads
/// as "scroll for more" and is still a target a finger hits. Whatever the rows'
/// heights (large text, a label on two lines), the edge never leaves a sliver of a
/// row that is too thin to see or to tap.
///
/// Rows that fit within [maxHeight] are shown whole and do not scroll. One whole row
/// and the peek of the next are always shown, also where that is taller than
/// [maxHeight].
class RowPeek extends StatelessWidget {
  const RowPeek({
    required this.maxHeight,
    required this.children,
    this.spacing = 0,
    this.runSpacing = 0,
    this.peek = kRowPeek,
    super.key,
  });

  final double maxHeight;
  final double peek;
  final double spacing;
  final double runSpacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _RowPeekBox(
    maxHeight: maxHeight,
    peek: peek,
    child: SingleChildScrollView(
      child: _RowTops(
        child: Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children,
        ),
      ),
    ),
  );
}

/// The height of a scrolling strip of rows that start at [rowTops] and are [content]
/// tall together: all of them when they fit into [budget], else up to the last row
/// that shows [peek] of itself within [budget] (never the first: one row is whole).
double rowPeekHeight({
  required List<double> rowTops,
  required double content,
  required double budget,
  double peek = kRowPeek,
}) {
  if (content <= budget) return content;
  if (rowTops.length < 2) return budget;
  final tops = [...rowTops]..sort();
  var cut = tops[1];
  for (final top in tops.skip(2)) {
    if (top + peek <= budget) cut = top;
  }
  return cut + peek;
}

/// Reports where the rows of its [Wrap] start, for [_RenderRowPeekBox] above the
/// scrollable to read.
class _RowTops extends SingleChildRenderObjectWidget {
  const _RowTops({required Wrap super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRowTops();
}

class _RenderRowTops extends RenderProxyBox {
  List<double> tops = const [];
  double content = 0;

  @override
  void performLayout() {
    super.performLayout();
    final rows = child! as RenderWrap;
    final found = <double>{};
    for (
      var tile = rows.firstChild;
      tile != null;
      tile = rows.childAfter(tile)
    ) {
      found.add((tile.parentData! as WrapParentData).offset.dy);
    }
    tops = found.toList();
    content = size.height;
  }
}

class _RowPeekBox extends SingleChildRenderObjectWidget {
  const _RowPeekBox({
    required this.maxHeight,
    required this.peek,
    required Widget super.child,
  });

  final double maxHeight;
  final double peek;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowPeekBox(maxHeight, peek);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderRowPeekBox)
      ..maxHeight = maxHeight
      ..peek = peek;
  }
}

class _RenderRowPeekBox extends RenderProxyBox {
  _RenderRowPeekBox(this._maxHeight, this._peek);

  double get maxHeight => _maxHeight;
  double _maxHeight;
  set maxHeight(double value) {
    if (value == _maxHeight) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  double get peek => _peek;
  double _peek;
  set peek(double value) {
    if (value == _peek) return;
    _peek = value;
    markNeedsLayout();
  }

  /// The rows below the scrollable in [from].
  static _RenderRowTops? _rowsOf(RenderObject from) {
    _RenderRowTops? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is _RenderRowTops) {
        found = child;
      } else {
        child.visitChildren(visit);
      }
    }

    from.visitChildren(visit);
    return found;
  }

  @override
  void performLayout() {
    final child = this.child!;
    // Loose in height both times, never tight: a tight box would make the scrollable
    // a relayout boundary, and rows that change later would no longer reach this one.
    BoxConstraints atMost(double height) => constraints.copyWith(
      minHeight: 0,
      maxHeight: height.clamp(0, constraints.maxHeight),
    );
    // The rows are laid out with the scrollable; what is left to decide is how much
    // of them the scrollable shows.
    child.layout(atMost(maxHeight), parentUsesSize: true);
    final rows = _rowsOf(child);
    if (rows != null) {
      final height = rowPeekHeight(
        rowTops: rows.tops,
        content: rows.content,
        budget: maxHeight,
        peek: peek,
      );
      if ((height - child.size.height).abs() > precisionErrorTolerance) {
        child.layout(atMost(height), parentUsesSize: true);
      }
    }
    size = constraints.constrain(child.size);
  }
}
