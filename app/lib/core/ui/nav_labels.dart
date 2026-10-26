import 'package:flutter/widgets.dart';

/// The style for a bottom navigation bar's labels (specs/09): [base], or smaller until
/// the longest of [labels] fits its share of the width, never below [minSize]. The
/// text scale counts as the bar applies it (capped by the caller, e.g. at 1.3).
/// [fits] is false when even [minSize] is too wide: the caller then uses its short
/// labels, so a label never breaks inside a word ("Stundenpl / an").
/// [label] that never breaks between its words: a navigation label is one line.
String unbreakable(String label) => label.replaceAll(' ', '\u00A0');

({TextStyle style, bool fits}) fitNavLabels(
  BuildContext context,
  List<String> labels, {
  required TextStyle base,
  double minSize = 11,
  double maxScale = 1.3,
}) {
  // Measured as the label draws it: the inherited style (the app's font) under it.
  final drawn = DefaultTextStyle.of(context).style.merge(base);
  final scaler = MediaQuery.textScalerOf(context)
      .clamp(maxScaleFactor: maxScale);
  // The destination's own padding takes a little of its share.
  final slot = MediaQuery.sizeOf(context).width / labels.length - 16;
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: drawn),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  final size = base.fontSize ?? 14;
  if (widest <= slot) return (style: base, fits: true);
  final fitted = size * slot / widest;
  if (fitted < minSize) {
    return (style: base.copyWith(fontSize: minSize), fits: false);
  }
  return (style: base.copyWith(fontSize: fitted), fits: true);
}
