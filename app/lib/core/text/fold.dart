/// Folds case, umlauts and accents together, the same way `app.fold` does in the
/// database, so "klopapier" finds "Toilettenpapier" and "ae" finds "ä".
String fold(String text) {
  const from = 'áàâéèêíìîóòôúùûñç';
  const to = 'aaaeeeiiiooouuunc';
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    switch (c) {
      case 'ä':
        out.write('ae');
      case 'ö':
        out.write('oe');
      case 'ü':
        out.write('ue');
      case 'ß':
        out.write('ss');
      default:
        final i = from.indexOf(c);
        out.write(i < 0 ? c : to[i]);
    }
  }
  return out.toString();
}
