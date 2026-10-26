// Candidate-only contrast proofs. Unknown paint/compositing always retains SDK checks.
import 'dart:math' as math;
import 'dart:ui' show ColorSpace, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class PaintContrastReport {
  PaintContrastReport(this.rows);
  final List<Map<String, Object?>> rows;
  bool get failed => rows.any((r) => r['classification'] == 'PROVEN_FAIL');
  Map<String, Object?> toJson() => {
    'paragraphs': rows.length,
    'provenPass': rows
        .where((r) => r['classification'] == 'PROVEN_PASS')
        .length,
    'provenFail': rows
        .where((r) => r['classification'] == 'PROVEN_FAIL')
        .length,
    'unsupported': rows
        .where((r) => r['classification'] == 'UNSUPPORTED')
        .length,
    'details': rows,
  };
}

class _Run {
  _Run(this.start, this.end, this.text, this.style);
  final int start;
  final int end;
  final String text;
  final TextStyle style;
}

/// Ratio uses specified paint colors, not anti-aliased edge pixels.
double paintedContrastRatio(Color foreground, Color background) {
  final foregroundPaint = Color.alphaBlend(foreground, background);
  final a = foregroundPaint.computeLuminance();
  final b = background.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

double requiredPaintContrast(double size, FontWeight weight) =>
    size >= 24 || weight.value >= FontWeight.w700.value && size >= 56 / 3
    ? 3
    : 4.5;

bool _translation(RenderObject object) {
  final matrix = object.getTransformTo(null);
  final expected = Matrix4.identity()
    ..setTranslationRaw(matrix.storage[12], matrix.storage[13], 0);
  return matrix == expected;
}

Rect _globalRect(RenderBox object, Rect rect) =>
    MatrixUtils.transformRect(object.getTransformTo(null), rect);

// These exact SDK classes paint only their child; subclasses may override paint.
bool _passThrough(RenderObject object) => {
  RenderView,
  RenderPadding,
  RenderConstrainedBox,
  RenderPositionedBox,
  RenderRepaintBoundary,
  RenderPointerListener,
  RenderMouseRegion,
  RenderSemanticsAnnotations,
  RenderSemanticsGestureHandler,
  RenderExcludeSemantics,
  RenderMergeSemantics,
  RenderIgnorePointer,
  RenderAbsorbPointer,
  RenderLimitedBox,
  RenderIntrinsicWidth,
  RenderIntrinsicHeight,
}.contains(object.runtimeType);

bool _boundedPainter(RenderObject object, Map<RenderObject, Color> colored) {
  if (object is RenderParagraph) {
    return object.runtimeType == RenderParagraph &&
        object.overflow != TextOverflow.visible &&
        object.childCount == 0;
  }
  if (object is RenderDecoratedBox) {
    final decoration = object.decoration;
    if (object.runtimeType != RenderDecoratedBox ||
        decoration.runtimeType != BoxDecoration ||
        (decoration as BoxDecoration).boxShadow?.isNotEmpty == true ||
        decoration.image != null ||
        decoration.gradient != null) {
      return false;
    }
  } else if (object is RenderPhysicalModel) {
    if (object.runtimeType != RenderPhysicalModel || object.elevation != 0) {
      return false;
    }
  } else if (!_passThrough(object) &&
      !colored.containsKey(object) &&
      object.runtimeType != RenderFlex) {
    return false;
  }
  var bounded = true;
  object.visitChildren((child) {
    if (object is! RenderBox ||
        child is! RenderBox ||
        !_boundedPainter(child, colored)) {
      bounded = false;
      return;
    }
    final childBounds = MatrixUtils.transformRect(
      child.getTransformTo(object),
      child.paintBounds,
    );
    if (!(Offset.zero & object.size).contains(childBounds.topLeft) ||
        !(Offset.zero & object.size).contains(
          childBounds.bottomRight - const Offset(0.001, 0.001),
        )) {
      bounded = false;
    }
  });
  return bounded;
}

String? _siblingProblem(
  RenderObject parent,
  RenderObject branch,
  List<Rect> boxes,
  Map<RenderObject, Color> colored,
) {
  String? problem;
  parent.visitChildren((child) {
    if (identical(child, branch)) return;
    if (child is! RenderBox || !_boundedPainter(child, colored)) {
      problem = 'Sibling paint bounds are not proven';
    } else if (boxes.any(
      (box) => _globalRect(child, child.paintBounds).overlaps(box),
    )) {
      problem = 'Sibling painting overlaps text';
    }
  });
  return problem;
}

({Color? color, String? reason}) _background(
  RenderParagraph paragraph,
  List<Rect> boxes,
  Map<RenderObject, Color> colored,
  Element? element,
  Set<RenderObject> roots,
) {
  Color? background;
  RenderObject branch = paragraph;
  final inkController = element == null ? null : Material.maybeOf(element);
  for (
    RenderObject? current = paragraph.parent;
    current != null;
    branch = current, current = current.parent
  ) {
    if (!_translation(current)) {
      return (color: background, reason: 'Non-translation transform');
    }
    if (roots.contains(current)) {
      continue;
    }
    if (current is RenderOpacity) {
      if (current.runtimeType != RenderOpacity || current.opacity != 1) {
        return (color: background, reason: 'Opacity changes painted colors');
      }
    } else if (current is RenderAnimatedOpacity) {
      if (current.runtimeType != RenderAnimatedOpacity ||
          current.opacity.value != 1) {
        return (
          color: background,
          reason: 'Animated opacity changes painted colors',
        );
      }
    } else if (current is RenderStack) {
      return (color: background, reason: 'Stack paint order is unsupported');
    } else if (current is RenderDecoratedBox ||
        current is RenderPhysicalModel ||
        colored.containsKey(current)) {
      Color? fill;
      Rect? interior;
      if (current is! RenderBox) {
        return (color: background, reason: 'Unknown background bounds');
      }
      final rect = Offset.zero & current.size;
      if (current is RenderDecoratedBox) {
        final decoration = current.decoration;
        if (current.runtimeType != RenderDecoratedBox ||
            decoration.runtimeType != BoxDecoration) {
          return (color: background, reason: 'Custom decoration');
        }
        final box = decoration as BoxDecoration;
        if (current.position != DecorationPosition.background ||
            box.image != null ||
            box.gradient != null ||
            box.backgroundBlendMode != null &&
                box.backgroundBlendMode != BlendMode.srcOver) {
          return (
            color: background,
            reason: 'Foreground/gradient/image/blended decoration',
          );
        }
        fill = box.color;
        final radius = box.shape == BoxShape.circle
            ? BorderRadius.circular(rect.shortestSide / 2)
            : box.borderRadius?.resolve(current.configuration.textDirection) ??
                  BorderRadius.zero;
        final edges =
            box.border?.dimensions.resolve(
              current.configuration.textDirection,
            ) ??
            EdgeInsets.zero;
        final inset =
            math.max(
              math.max(edges.left, edges.right),
              math.max(edges.top, edges.bottom),
            ) +
            0.5;
        interior = radius.toRRect(rect).safeInnerRect.deflate(inset);
      } else if (current is RenderPhysicalModel) {
        if (current.runtimeType != RenderPhysicalModel ||
            current.clipper != null) {
          return (color: background, reason: 'Custom physical clip');
        }
        fill = current.color;
        final radius = current.shape == BoxShape.circle
            ? BorderRadius.circular(rect.shortestSide / 2)
            : current.borderRadius ?? BorderRadius.zero;
        interior = radius.toRRect(rect).safeInnerRect.deflate(0.5);
      } else {
        fill = colored[current];
        interior = rect.deflate(0.5);
      }
      if (background == null && fill != null) {
        if (fill.a != 1) {
          return (
            color: null,
            reason: 'Translucent background requires a compositing proof',
          );
        }
        if (fill.colorSpace != ColorSpace.sRGB) {
          return (color: null, reason: 'Non-sRGB background');
        }
        final globalInterior = _globalRect(current, interior);
        if (!boxes.every(
          (box) =>
              globalInterior.contains(box.topLeft) &&
              globalInterior.contains(
                box.bottomRight - const Offset(0.001, 0.001),
              ),
        )) {
          return (
            color: null,
            reason: 'Text reaches a border or unproven fill region',
          );
        }
        background = fill;
      }
    } else if (identical(current, inkController)) {
      // Obtain the controller through public Material.maybeOf, never a private type name.
      // Its SDK public debug getter exposes whether it actually paints any ink.
      try {
        final Object? features = (current as dynamic).debugInkFeatures;
        if (features != null && (features is! List || features.isNotEmpty)) {
          return (color: background, reason: 'Material ink paints below text');
        }
      } catch (_) {
        return (color: background, reason: 'Material ink state unavailable');
      }
    } else if (current.runtimeType == RenderFlex ||
        current.runtimeType == RenderCustomMultiChildLayoutBox) {
      final reason = _siblingProblem(current, branch, boxes, colored);
      if (reason != null) return (color: background, reason: reason);
    } else if (!_passThrough(current)) {
      return (
        color: background,
        reason: 'Unsupported ancestor paint: ${current.runtimeType}',
      );
    }
  }
  return (
    color: background,
    reason: background == null ? 'No opaque background proof' : null,
  );
}

PaintContrastReport auditPaintContrast(WidgetTester tester) {
  final rows = <Map<String, Object?>>[];
  final paragraphs = <RenderParagraph>[];
  final colored = <RenderObject, Color>{};
  for (final element in find.byType(ColoredBox).evaluate()) {
    colored[element.renderObject!] = (element.widget as ColoredBox).color;
  }
  void renderVisit(RenderObject object) {
    if (object is RenderParagraph) paragraphs.add(object);
    object.visitChildren(renderVisit);
  }

  for (final view in tester.binding.renderViews) {
    renderVisit(view);
  }
  final roots = tester.binding.renderViews.toSet();
  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final creator = paragraph.debugCreator;
    final element = creator is DebugCreator ? creator.element : null;
    SemanticsNode? owner;
    for (
      RenderObject? r = paragraph;
      r != null && owner == null;
      r = r.parent
    ) {
      owner = r.debugSemantics;
    }
    final row = <String, Object?>{
      'text': text,
      'semanticsId': owner?.id,
      'classification': 'UNSUPPORTED',
    };
    rows.add(row);
    if (paragraph.runtimeType != RenderParagraph) {
      row['reason'] = 'Custom RenderParagraph paint is unsupported';
      continue;
    }
    var exempt = false;
    for (
      SemanticsNode? current = owner;
      current != null;
      current = current.parent
    ) {
      if (current.flagsCollection.isEnabled == Tristate.isFalse ||
          current.flagsCollection.isHidden ||
          current.isInvisible) {
        exempt = true;
      }
    }
    if (exempt) {
      row['reason'] = 'Disabled or hidden semantics; retains SDK exemption';
      continue;
    }
    String? reason;
    if (roots.any((r) => r.flutterView.devicePixelRatio != 1)) {
      reason = 'Paint proof supports logical DPR 1 captures only';
    }
    final runs = <_Run>[];
    var offset = 0;
    void spanVisit(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) {
        reason ??= 'Non-text inline span';
        return;
      }
      final style = inherited.merge(span.style);
      final content = span.text ?? '';
      if (content.isNotEmpty) {
        runs.add(_Run(offset, offset + content.length, content, style));
      }
      offset += content.length;
      for (final child in span.children ?? <InlineSpan>[]) {
        spanVisit(child, style);
      }
    }

    spanVisit(paragraph.text, const TextStyle());
    if (!_translation(paragraph)) {
      reason ??= 'Non-translation paragraph transform';
    }
    if (paragraph.overflow == TextOverflow.fade) {
      reason ??= 'Text fade changes glyph opacity';
    }
    final details = <Map<String, Object?>>[];
    var failed = false;
    for (final run in runs.where((r) => r.text.trim().isNotEmpty)) {
      final style = run.style;
      final fg = style.color;
      if (fg == null ||
          style.foreground != null ||
          style.background != null ||
          style.backgroundColor != null ||
          style.shadows?.isNotEmpty == true ||
          style.fontStyle == FontStyle.italic ||
          style.fontVariations?.isNotEmpty == true ||
          fg.colorSpace != ColorSpace.sRGB) {
        reason ??= 'Unsupported text paint';
        continue;
      }
      if (![
            'AtkinsonHyperlegibleNext',
            'BarlowSemiCondensed',
          ].contains(style.fontFamily) ||
          run.text.runes.any(
            (r) =>
                r > 0x24f &&
                r != 0x20ac &&
                r != 0x2026 &&
                r != 0x2013 &&
                r != 0x2014,
          )) {
        reason ??= 'Font fallback or colored glyphs are not proven';
        continue;
      }
      final boxes = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: run.start, extentOffset: run.end),
          )
          .map((b) => _globalRect(paragraph, b.toRect()))
          .where((b) => !b.isEmpty)
          .toList();
      if (boxes.isEmpty) {
        reason ??= 'No visible run geometry';
        continue;
      }
      final resolved = _background(paragraph, boxes, colored, element, roots);
      reason ??= resolved.reason;
      final bg = resolved.color;
      if (bg == null || style.fontSize == null) continue;
      final size = paragraph.textScaler.scale(style.fontSize!);
      final minimum = requiredPaintContrast(
        size,
        style.fontWeight ?? FontWeight.normal,
      );
      final ratio = paintedContrastRatio(fg, bg);
      details.add({
        'text': run.text,
        'foreground': fg.toARGB32(),
        'background': bg.toARGB32(),
        'effectiveSize': size,
        'weight': (style.fontWeight ?? FontWeight.normal).value,
        'ratio': ratio,
        'required': minimum,
      });
      if (ratio < minimum) failed = true;
    }
    row['runs'] = details;
    if (reason == null && details.isNotEmpty) {
      row['classification'] = failed ? 'PROVEN_FAIL' : 'PROVEN_PASS';
    } else {
      row['reason'] = reason ?? 'No audited runs';
    }
  }
  return PaintContrastReport(rows);
}
