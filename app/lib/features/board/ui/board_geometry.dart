/// The week board's column geometry in canvas units (specs/09 "The week board").
///
/// Every row of the board is laid out with this one class, so the zones line up: a label
/// gutter on the left, then seven day columns sharing the rest by flex. Today is wider
/// (1.45, the other days 1.0). There are no gaps between columns, so a presence band can
/// run across several of them. Pure arithmetic, so it is unit-testable without widgets.
class BoardGeometry {
  const BoardGeometry({required this.canvasWidth, this.todayIndex});

  /// Width of the label column, left of Monday.
  static const gutter = 168.0;

  static const dayCount = 7;
  static const todayFlex = 1.45;

  /// The full canvas width the board is drawn at.
  final double canvasWidth;

  /// Index 0–6 of today, or null when today is outside the week (all columns equal).
  final int? todayIndex;

  double _flex(int i) => i == todayIndex ? todayFlex : 1.0;

  double get _totalFlex {
    var total = 0.0;
    for (var i = 0; i < dayCount; i++) {
      total += _flex(i);
    }
    return total;
  }

  double _dayWidth(int i) => (canvasWidth - gutter) * _flex(i) / _totalFlex;

  /// Left edge of day column [i] (0 = Monday).
  double left(int i) {
    var x = gutter;
    for (var j = 0; j < i; j++) {
      x += _dayWidth(j);
    }
    return x;
  }

  /// Width of day column [i].
  double width(int i) => _dayWidth(i);

  /// Left edge of a span that starts at column [first].
  double spanLeft(int first) => left(first);

  /// Width of a span from column [first] through [last], both inclusive.
  double spanWidth(int first, int last) {
    var w = 0.0;
    for (var i = first; i <= last; i++) {
      w += _dayWidth(i);
    }
    return w;
  }
}
