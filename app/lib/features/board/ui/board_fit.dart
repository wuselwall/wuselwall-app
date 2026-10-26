import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shows the first of [children] whose natural width fits the width it is given, and
/// the last one when none does: a line on the board that says less rather than ending
/// in an ellipsis (specs/09 "Degradation rules"). Order the children from the fullest
/// form to the shortest; the last should be able to shrink (an ellipsis) so it never
/// overflows.
///
/// Unlike a LayoutBuilder it answers intrinsic sizes, so it works inside the header's
/// and footer's IntrinsicHeight rows. Only the chosen child is painted, hit-tested and
/// read out.
class FirstThatFits extends MultiChildRenderObjectWidget {
  const FirstThatFits({required super.children, super.key})
    : assert(children.length > 0);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFirstThatFits();
}

class _FitParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFirstThatFits extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FitParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FitParentData> {
  RenderBox? _chosen;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitParentData) {
      child.parentData = _FitParentData();
    }
  }

  /// The first child whose maximum intrinsic width is at most [width], else the last.
  RenderBox? _pick(double width) {
    var child = firstChild;
    while (child != null) {
      final next = childAfter(child);
      if (next == null) return child;
      if (child.getMaxIntrinsicWidth(double.infinity) <= width) return child;
      child = next;
    }
    return null;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      lastChild?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _pick(width)?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _pick(width)?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = _pick(constraints.maxWidth);
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(constraints.loosen()));
  }

  @override
  void performLayout() {
    _chosen = _pick(constraints.maxWidth);
    var child = firstChild;
    while (child != null) {
      // The others are laid out too, so nothing reads the size of a box that never
      // had one; they are simply not painted.
      child.layout(constraints.loosen(), parentUsesSize: child == _chosen);
      (child.parentData! as _FitParentData).offset = Offset.zero;
      child = childAfter(child);
    }
    final chosen = _chosen;
    size = chosen == null
        ? constraints.smallest
        : constraints.constrain(chosen.size);
    if (chosen != null) {
      // Centred across the height, like the Row it stands in for.
      (chosen.parentData! as _FitParentData).offset = Offset(
        0,
        math.max(0, (size.height - chosen.size.height) / 2),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final chosen = _chosen;
    if (chosen == null) return;
    context.paintChild(
      chosen,
      offset + (chosen.parentData! as _FitParentData).offset,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final chosen = _chosen;
    if (chosen == null) return false;
    final offset = (chosen.parentData! as _FitParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) =>
          chosen.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final chosen = _chosen;
    if (chosen != null) visitor(chosen);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      child == _chosen ? null : Rect.zero;
}
