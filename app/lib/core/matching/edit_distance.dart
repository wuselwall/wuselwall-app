/// Optimal-string-alignment distance: insert, delete, replace and swapping two
/// neighbours each cost one, so "tomtaen" is one step from "tomaten", not two.
///
/// Returns `max + 1` as soon as the result is certain to exceed [max]: first when
/// the lengths alone differ by more than [max], then when a whole row of the table
/// is already above it. The fuzzy layer asks for 1 or 2 against thousands of
/// words, so most pairs are rejected before any table is filled.
int damerauLevenshtein(String a, String b, {int max = 1 << 20}) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > max) return max + 1;
  if (a.isEmpty) return b.length > max ? max + 1 : b.length;
  if (b.isEmpty) return a.length > max ? max + 1 : a.length;

  var twoAgo = List<int>.filled(b.length + 1, 0);
  var previous = List<int>.generate(b.length + 1, (j) => j);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var d = previous[j - 1] + cost;
      if (previous[j] + 1 < d) d = previous[j] + 1;
      if (current[j - 1] + 1 < d) d = current[j - 1] + 1;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
          twoAgo[j - 2] + 1 < d) {
        d = twoAgo[j - 2] + 1;
      }
      current[j] = d;
      if (d < rowMin) rowMin = d;
    }
    if (rowMin > max) return max + 1;
    final spare = twoAgo;
    twoAgo = previous;
    previous = current;
    current = spare;
  }
  final result = previous[b.length];
  return result > max ? max + 1 : result;
}
