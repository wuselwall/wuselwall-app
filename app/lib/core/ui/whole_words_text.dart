import 'package:flutter/widgets.dart';

/// Text that may wrap between its words but never inside one (specs/17): when its
/// longest word does not fit the width it gets, the font shrinks until it does,
/// rather than breaking "Müll rausbringe / n" on a small phone. Words are separated
/// by ordinary spaces only, so a span joined with non-breaking spaces ("9:55 – 10:40")
/// counts as one word and shrinks as a whole.
class WholeWordsText extends StatelessWidget {
  const WholeWordsText(
    this.text, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: constraints.hasBoundedWidth
          ? fitWholeWords(context, text, style, constraints.maxWidth)
          : style,
    ),
  );
}

/// [style], or smaller until the longest word of [text] fits [width] on one line,
/// measured as the Text draws it (the inherited style under [style]).
TextStyle? fitWholeWords(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  final drawn = DefaultTextStyle.of(context).style.merge(style);
  final scaler = MediaQuery.textScalerOf(context);
  final words = [
    for (final w in text.split(' '))
      if (w.isNotEmpty) w,
  ];
  if (words.isEmpty) return style;
  double widestAt(double size) {
    var widest = 0.0;
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(
          text: word,
          style: drawn.copyWith(fontSize: size),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  final base = drawn.fontSize ?? 14;
  var size = base;
  // Measured again after each step: Android's font scaling is not linear (a small
  // font is scaled up by more), so one proportional step can still be too wide.
  for (var i = 0; i < 6; i++) {
    final widest = widestAt(size);
    if (widest <= width) break;
    size = size * width / widest * 0.98;
  }
  if (size == base) return style;
  return (style ?? const TextStyle()).copyWith(fontSize: size);
}
