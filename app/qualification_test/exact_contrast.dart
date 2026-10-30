// Exact text contrast: the style's own foreground over the painted background.
//
// Flutter's textContrastGuideline estimates both colours from a histogram of the
// text's box inflated by four pixels: the most frequent colour below the average
// lightness counts as the text. A table border, a cell tint or a button outline
// inside that margin is more frequent than a 12 px glyph's solid pixels, so the
// guideline reports the border against the paper (a ratio near 1.3) for text
// whose real ratio is far above 4.5. This audit removes that guess for the cases
// where no guess is needed: the foreground is the resolved TextStyle colour, the
// background is the one colour the glyph area is painted on, and every sampled
// pixel must be that background, that foreground or an anti-aliased blend of the
// two. Anything else (gradients, overlapping siblings, opacity, fades, shaders,
// translucent text) stays UNDECIDED and the SDK verdict stands for its node.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'paint_contrast.dart' show paintedContrastRatio, requiredPaintContrast;

/// Per-channel distance a sampled pixel may have from the fg–bg blend line.
/// Anti-aliasing composites coverage per channel in sRGB, so real blends sit
/// within rounding of the line; a wider band would absorb a near-paper tint
/// (paper #f7f4ee against white differs by 9 in blue) as if it were a blend.
const int _blendTolerance = 4;

/// The share of sampled pixels that must be foreground, background or a blend.
const double _minimumCoverage = 0.96;

/// The share of sampled pixels that must not be plain background, or the text
/// is not visible in the capture and nothing is proven about it.
const double _minimumInk = 0.005;

/// The least share of the sample a second flat background must hold to count
/// as one (a day number half on its "today" ring, a time beside a band).
const double _secondBackgroundShare = 0.02;

/// Icon fonts paint glyphs from the Private Use Area; they are graphics, not
/// text, and the SDK guideline never considers them either.
bool _isIconRun(String text, TextStyle style) {
  final family = style.fontFamily ?? '';
  if (family.contains('MaterialIcons') || family.contains('CupertinoIcons')) {
    return true;
  }
  final runes = text.runes.where((r) => r != 0x20 && r != 0xa0).toList();
  return runes.isNotEmpty && runes.every((r) => r >= 0xe000 && r <= 0xf8ff);
}

class ExactContrastRow {
  ExactContrastRow({
    required this.semanticsId,
    required this.text,
    required this.classification,
    this.reason,
    this.foreground,
    this.background,
    this.background2,
    this.ratio,
    this.required,
    this.effectiveSize,
    this.weight,
    this.coverage,
    this.sampled,
  });

  final int semanticsId;
  final String text;

  /// PASS, FAIL or UNDECIDED.
  final String classification;
  final String? reason;
  final int? foreground;
  final int? background;

  /// A second flat background the run spans, when there is one.
  final int? background2;
  final double? ratio;
  final double? required;
  final double? effectiveSize;
  final int? weight;
  final double? coverage;
  final int? sampled;

  Map<String, Object?> toJson() => {
    'semanticsId': semanticsId,
    'text': text,
    'classification': classification,
    if (reason != null) 'reason': reason,
    if (foreground != null) 'foreground': foreground,
    if (background != null) 'background': background,
    if (background2 != null) 'background2': background2,
    if (ratio != null) 'ratio': ratio,
    if (required != null) 'required': required,
    if (effectiveSize != null) 'effectiveSize': effectiveSize,
    if (weight != null) 'weight': weight,
    if (coverage != null) 'coverage': coverage,
    if (sampled != null) 'sampled': sampled,
  };

  String describe() =>
      'SemanticsNode#$semanticsId "$text": painted '
      '${_hex(foreground)} on ${_hex(background)}'
      '${background2 == null ? '' : ' and ${_hex(background2)}'} is '
      '${ratio?.toStringAsFixed(2)}:1, needs ${required?.toStringAsFixed(1)}:1 '
      'at ${effectiveSize?.toStringAsFixed(1)} px, weight $weight.';
}

String _hex(int? argb) =>
    argb == null ? '?' : '#${argb.toRadixString(16).padLeft(8, '0')}';

class ExactContrastReport {
  ExactContrastReport(this.rows);

  final List<ExactContrastRow> rows;

  Iterable<ExactContrastRow> get failures =>
      rows.where((r) => r.classification == 'FAIL');

  /// Nodes whose every audited paragraph lies under a shader mask (the edge
  /// fade of a scrolling row). Text under a gradient is outside the automated
  /// check's scope (specs/accessibility-and-ui-qualification.md, scope table):
  /// the SDK's estimate there is neither proven nor refuted, so it is listed
  /// for review rather than failing the case.
  Set<int> get maskedNodes {
    final byNode = <int, List<ExactContrastRow>>{};
    for (final row in rows) {
      byNode.putIfAbsent(row.semanticsId, () => []).add(row);
    }
    return {
      for (final entry in byNode.entries)
        if (entry.value.every(
          (r) => r.classification == 'UNDECIDED' && r.reason == 'Shader mask',
        ))
          entry.key,
    };
  }

  /// Nodes whose every audited paragraph is a decided PASS. An SDK finding for
  /// such a node is a misattributed estimate and may be superseded.
  Set<int> get provenNodes {
    final byNode = <int, List<ExactContrastRow>>{};
    for (final row in rows) {
      byNode.putIfAbsent(row.semanticsId, () => []).add(row);
    }
    return {
      for (final entry in byNode.entries)
        if (entry.value.every((r) => r.classification == 'PASS')) entry.key,
    };
  }

  Map<String, Object?> toJson() => {
    'paragraphs': rows.length,
    'pass': rows.where((r) => r.classification == 'PASS').length,
    'fail': rows.where((r) => r.classification == 'FAIL').length,
    'undecided': rows.where((r) => r.classification == 'UNDECIDED').length,
    'details': [for (final row in rows) row.toJson()],
  };
}

/// One SDK contrast failure, as `textContrastGuideline` prints it: the node's
/// description, then the ratio it estimated.
final RegExp _sdkBlockStart = RegExp(
  r'^SemanticsNode#(\d+)\(',
  multiLine: true,
);

/// Splits an SDK textContrast reason into its per-node blocks.
Map<int, List<String>> sdkContrastBlocks(String reason) {
  final starts = _sdkBlockStart.allMatches(reason).toList();
  final blocks = <int, List<String>>{};
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : reason.length;
    final block = reason.substring(starts[i].start, end).trim();
    blocks.putIfAbsent(int.parse(starts[i].group(1)!), () => []).add(block);
  }
  return blocks;
}

/// The SDK findings that stand after the exact audit: every block whose node is
/// not proven. [superseded] receives the blocks that the exact audit replaced.
String? retainedSdkContrast(
  String reason,
  Set<int> proven, {
  List<String>? superseded,
}) {
  final blocks = sdkContrastBlocks(reason);
  if (blocks.isEmpty) return reason; // unparsed: retained verbatim
  final kept = <String>[];
  for (final entry in blocks.entries) {
    if (proven.contains(entry.key)) {
      superseded?.addAll(entry.value);
    } else {
      kept.addAll(entry.value);
    }
  }
  return kept.isEmpty ? null : kept.join('\n\n');
}

class _Run {
  _Run(this.start, this.end, this.text, this.style);
  final int start;
  final int end;
  final String text;
  final TextStyle style;
}

class _Capture {
  _Capture(this.data, this.width, this.height);
  final ByteData data;
  final int width;
  final int height;

  int argbAt(int x, int y) {
    final rgba = data.getUint32((y * width + x) * 4);
    return (rgba >> 8) | ((rgba & 0xff) << 24);
  }
}

SemanticsNode? _owningNode(RenderObject paragraph) {
  SemanticsNode? node;
  for (RenderObject? r = paragraph; r != null && node == null; r = r.parent) {
    node = r.debugSemantics;
  }
  while (node != null && node.isMergedIntoParent && node.parent != null) {
    node = node.parent;
  }
  return node;
}

bool _exempt(SemanticsNode node) {
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    if (n.isInvisible ||
        n.flagsCollection.isHidden ||
        n.flagsCollection.isEnabled == ui.Tristate.isFalse) {
      return true;
    }
  }
  return false;
}

/// Ancestors that change the painted colour of the glyphs themselves. Anything
/// that paints beside or over the text with other colours (foreground painters,
/// stacks, siblings, the debug banner) is caught by the coverage check instead:
/// its pixels are not on the foreground–background line.
String? _ancestorProblem(RenderObject paragraph) {
  for (RenderObject? r = paragraph.parent; r != null; r = r.parent) {
    if (r is RenderOpacity && r.opacity < 1) return 'Opacity below 1';
    if (r is RenderAnimatedOpacity && r.opacity.value < 1) {
      return 'Animated opacity below 1';
    }
    if (r is RenderShaderMask) return 'Shader mask';
    if (r is RenderBackdropFilter) return 'Backdrop filter';
    final type = r.runtimeType.toString();
    if (type.contains('ColorFilter') || type.contains('ImageFilter')) {
      return 'Colour or image filter';
    }
  }
  return null;
}

/// Whether [argb] lies on the straight blend between [fg] and [bg].
bool _isBlend(int argb, int fg, int bg) {
  if (argb == fg || argb == bg) return true;
  final c = [(argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff];
  final f = [(fg >> 16) & 0xff, (fg >> 8) & 0xff, fg & 0xff];
  final b = [(bg >> 16) & 0xff, (bg >> 8) & 0xff, bg & 0xff];
  // The blend parameter from the channel with the largest fg–bg difference.
  var lead = 0;
  for (var i = 1; i < 3; i++) {
    if ((f[i] - b[i]).abs() > (f[lead] - b[lead]).abs()) lead = i;
  }
  final span = f[lead] - b[lead];
  if (span == 0) return false;
  final t = (c[lead] - b[lead]) / span;
  if (t < -0.02 || t > 1.02) return false;
  for (var i = 0; i < 3; i++) {
    final expected = b[i] + t * (f[i] - b[i]);
    if ((c[i] - expected).abs() > _blendTolerance) return false;
  }
  return true;
}

/// Audits every painted paragraph the SDK guideline would consider.
Future<ExactContrastReport> auditExactContrast(WidgetTester tester) async {
  final rows = <ExactContrastRow>[];
  for (final renderView in tester.binding.renderViews) {
    if (renderView.flutterView.devicePixelRatio != 1) {
      // The capture and the paint bounds share a coordinate space only at DPR 1.
      continue;
    }
    final layer = renderView.debugLayer! as OffsetLayer;
    late int width;
    late int height;
    final data = await tester.binding.runAsync<ByteData?>(() async {
      final image = await layer.toImage(renderView.paintBounds);
      width = image.width;
      height = image.height;
      final bytes = await image.toByteData();
      image.dispose();
      return bytes;
    });
    if (data == null) continue;
    final capture = _Capture(data, width, height);
    final paragraphs = <RenderParagraph>[];
    void visit(RenderObject object) {
      if (object is RenderParagraph) paragraphs.add(object);
      object.visitChildren(visit);
    }

    visit(renderView);
    for (final paragraph in paragraphs) {
      final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
      if (text.trim().isEmpty) continue;
      final node = _owningNode(paragraph);
      if (node == null || _exempt(node)) continue;
      rows.addAll(_auditParagraph(paragraph, node.id, text, capture));
    }
  }
  return ExactContrastReport(rows);
}

List<ExactContrastRow> _auditParagraph(
  RenderParagraph paragraph,
  int nodeId,
  String text,
  _Capture capture,
) {
  ExactContrastRow undecided(String reason) => ExactContrastRow(
    semanticsId: nodeId,
    text: text,
    classification: 'UNDECIDED',
    reason: reason,
  );
  if (paragraph.runtimeType != RenderParagraph) {
    return [undecided('Custom paragraph paint')];
  }
  // A fade changes the glyphs only when the text overflows and the shader paints.
  if (paragraph.overflow == TextOverflow.fade &&
      // ignore: invalid_use_of_visible_for_testing_member, this is test code
      paragraph.debugHasOverflowShader) {
    return [undecided('Text fade changes glyph opacity')];
  }
  final ancestor = _ancestorProblem(paragraph);
  if (ancestor != null) return [undecided(ancestor)];

  final runs = <_Run>[];
  var offset = 0;
  String? spanProblem;
  void spanVisit(InlineSpan span, TextStyle inherited) {
    if (span is! TextSpan) {
      spanProblem ??= 'Inline widget span';
      offset += 1;
      return;
    }
    final style = inherited.merge(span.style);
    final content = span.text ?? '';
    if (content.isNotEmpty) {
      runs.add(_Run(offset, offset + content.length, content, style));
    }
    offset += content.length;
    for (final child in span.children ?? const <InlineSpan>[]) {
      spanVisit(child, style);
    }
  }

  spanVisit(paragraph.text, const TextStyle());
  if (spanProblem != null) return [undecided(spanProblem!)];

  final transform = paragraph.getTransformTo(null);
  final sx = Offset(transform.storage[0], transform.storage[1]).distance;
  final sy = Offset(transform.storage[4], transform.storage[5]).distance;
  final scale = math.min(sx, sy);
  if (scale <= 0) return [undecided('Degenerate transform')];

  final rows = <ExactContrastRow>[];
  var iconRuns = 0;
  for (final run in runs.where((r) => r.text.trim().isNotEmpty)) {
    final style = run.style;
    if (_isIconRun(run.text, style)) {
      iconRuns++;
      continue;
    }
    final fg = style.color;
    if (fg == null) {
      rows.add(undecided('No resolved text colour'));
      continue;
    }
    if (style.foreground != null ||
        style.background != null ||
        style.backgroundColor != null ||
        style.shadows?.isNotEmpty == true ||
        fg.colorSpace != ui.ColorSpace.sRGB) {
      rows.add(undecided('Painted or shadowed text'));
      continue;
    }
    if (fg.a == 0) {
      rows.add(undecided('Fully transparent text'));
      continue;
    }
    final size = style.fontSize;
    if (size == null) {
      rows.add(undecided('No resolved font size'));
      continue;
    }
    final boxes = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: run.start, extentOffset: run.end),
        )
        .map((b) => MatrixUtils.transformRect(transform, b.toRect()))
        .where((b) => !b.isEmpty)
        .toList();
    if (boxes.isEmpty) {
      rows.add(undecided('No visible run geometry'));
      continue;
    }
    // One box per glyph: a background the text sits on fills at least half
    // of some glyph's box, so a bar or an indicator beside the glyphs (inside
    // the inflated sample, even inside the line box) does not count.
    final glyphBoxes = <Rect>[
      for (var i = run.start; i < run.end; i++)
        if (run.text[i - run.start].trim().isNotEmpty)
          for (final b in paragraph.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          ))
            MatrixUtils.transformRect(transform, b.toRect()),
    ].where((b) => !b.isEmpty).toList();
    // The sample: every pixel of the glyph boxes inflated by one, by index.
    final pixels = <int, int>{};
    final bounds = Rect.fromLTWH(
      0,
      0,
      capture.width.toDouble(),
      capture.height.toDouble(),
    );
    for (final box in boxes) {
      final rect = box.inflate(1).intersect(bounds);
      if (rect.isEmpty) continue;
      for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
        for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
          pixels.putIfAbsent(y * capture.width + x, () => capture.argbAt(x, y));
        }
      }
    }
    final sampled = pixels.length;
    if (sampled == 0) {
      rows.add(undecided('Run is outside the capture'));
      continue;
    }
    final histogram = <int, int>{};
    for (final c in pixels.values) {
      histogram.update(c, (n) => n + 1, ifAbsent: () => 1);
    }
    final byCount = histogram.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // The text's painted colour on a background: the style colour, or for
    // translucent text the style colour composited onto that background.
    int inkOn(int bg) => Color.alphaBlend(fg, Color(bg)).toARGB32();
    // Backgrounds are plateaus: colours holding a real share of the sample
    // whose pixels mostly sit among pixels of the same colour. Anti-aliasing
    // never forms one, however many pixels share a stem's coverage value.
    final plateaus = <int>[];
    for (final entry in byCount) {
      if (entry.value < _secondBackgroundShare * sampled) break;
      final c = entry.key;
      if ((c >> 24) & 0xff != 0xff || inkOn(c) == c) continue;
      if (fg.a == 1 && c == fg.toARGB32()) continue;
      var flat = 0;
      for (final index in pixels.keys) {
        if (pixels[index] != c) continue;
        final x = index % capture.width;
        final y = index ~/ capture.width;
        var same = 0;
        if (x > 0 && capture.argbAt(x - 1, y) == c) same++;
        if (x + 1 < capture.width && capture.argbAt(x + 1, y) == c) same++;
        if (y > 0 && capture.argbAt(x, y - 1) == c) same++;
        if (y + 1 < capture.height && capture.argbAt(x, y + 1) == c) same++;
        if (same >= 3) flat++;
      }
      if (flat * 2 >= entry.value) plateaus.add(c);
      if (plateaus.length == 2) break;
    }
    if (plateaus.isEmpty) {
      rows.add(undecided('No flat background under the text'));
      continue;
    }
    // A pixel is explained when it is a plateau or a straight blend between
    // the ink and a plateau. Which plateaus the text sits on is decided per
    // glyph box below, so neither the paper around an avatar's circle nor a
    // bar under a time counts as the text's background.
    bool inkish(int c) {
      for (final p in plateaus) {
        if (c != p && _isBlend(c, inkOn(p), p)) return true;
      }
      return false;
    }

    var covered = 0;
    var plain = 0;
    for (final c in pixels.values) {
      if (plateaus.contains(c)) {
        plain++;
        covered++;
      } else if (inkish(c)) {
        covered++;
      }
    }
    // Which plateaus the text sits on: those filling half of some glyph box
    // with their own pixels or ink blended onto them. A box without any ink
    // (a glyph clipped away, or outside the capture) sits on nothing.
    final sits = <int>{};
    for (final box in glyphBoxes) {
      final rect = box.intersect(bounds);
      if (rect.isEmpty) continue;
      final counts = <int, int>{};
      var total = 0;
      var inked = 0;
      for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
        for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
          total++;
          final c = capture.argbAt(x, y);
          // A plateau's own colour before any blend: a mid grey between the
          // ink and a white plateau is also on that pair's line.
          var owner = plateaus.contains(c) ? c : null;
          for (final p in plateaus) {
            if (owner != null) break;
            if (_isBlend(c, inkOn(p), p)) owner = p;
          }
          if (owner != null) {
            counts.update(owner, (n) => n + 1, ifAbsent: () => 1);
            if (c != owner) inked++;
          }
        }
      }
      if (inked == 0) continue;
      for (final entry in counts.entries) {
        if (entry.value * 2 >= total) sits.add(entry.key);
      }
    }
    final coverage = covered / sampled;
    final ink = 1 - plain / sampled;
    final spanned = plateaus.where(sits.contains).toList();
    final bg1 = spanned.isEmpty ? plateaus.first : spanned.first;
    final bg2 = spanned.length > 1 ? spanned[1] : null;
    final effectiveSize = paragraph.textScaler.scale(size) * scale;
    final weight = style.fontWeight ?? FontWeight.normal;
    final required = requiredPaintContrast(effectiveSize, weight);
    var ratio = paintedContrastRatio(fg, Color(bg1));
    if (bg2 != null) {
      ratio = math.min(ratio, paintedContrastRatio(fg, Color(bg2)));
    }
    String? reason;
    if (coverage < _minimumCoverage) {
      reason = 'More than one background or overlapping paint under the text';
    } else if (ink < _minimumInk || spanned.isEmpty) {
      reason = 'Text is not visible in the capture';
    }
    rows.add(
      ExactContrastRow(
        semanticsId: nodeId,
        text: run.text,
        classification: reason != null
            ? 'UNDECIDED'
            : ratio >= required
            ? 'PASS'
            : 'FAIL',
        reason: reason,
        foreground: fg.toARGB32(),
        background: bg1,
        background2: bg2,
        ratio: ratio,
        required: required,
        effectiveSize: effectiveSize,
        weight: weight.value,
        coverage: coverage,
        sampled: sampled,
      ),
    );
  }
  if (rows.isEmpty && iconRuns > 0) return rows; // icons only: nothing to audit
  if (rows.isEmpty) rows.add(undecided('No audited runs'));
  return rows;
}
