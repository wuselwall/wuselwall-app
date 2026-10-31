import 'package:wuselwall/core/text/fold.dart';

/// One shopping item as typed or dictated: the name, and how much of it.
///
/// [quantity] is a written amount with a unit ("2 l", "500 g"); [count] is a
/// plain number of pieces and is only set above one.
class ParsedItem {
  const ParsedItem({required this.name, this.quantity, this.count});

  final String name;
  final String? quantity;
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is ParsedItem &&
      other.name == name &&
      other.quantity == quantity &&
      other.count == count;

  @override
  int get hashCode => Object.hash(name, quantity, count);

  @override
  String toString() => 'ParsedItem($name, quantity: $quantity, count: $count)';
}

// A port of `parseShoppingText` in supabase/functions/_shared/shortcuts.ts, so the
// app files a typed "2 Liter Milch" exactly as the voice shortcut does. Keep the
// tables below in step with that file. The app adds the trailing forms ("Milch 1l",
// "Eier 6") that the server does not read.

const _numberWords = <String, int>{
  'ein': 1,
  'eine': 1,
  'einen': 1,
  'einem': 1,
  'einer': 1,
  'eins': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fuenf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'zwoelf': 12,
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'twelve': 12,
  'un': 1,
  'une': 1,
  'deux': 2,
  'trois': 3,
  'quatre': 4,
  'cinq': 5,
  'sept': 7,
  'huit': 8,
  'neuf': 9,
  'dix': 10,
  'onze': 11,
  'douze': 12,
  'uno': 1,
  'una': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
  'siete': 7,
  'ocho': 8,
  'nueve': 9,
  'diez': 10,
  'once': 11,
  'doce': 12,
};

// Spoken units to how they are written on the list. Folded keys.
const _units = <String, String>{
  'l': 'l',
  'liter': 'l',
  'litre': 'l',
  'liters': 'l',
  'litres': 'l',
  'ml': 'ml',
  'milliliter': 'ml',
  'g': 'g',
  'gramm': 'g',
  'gram': 'g',
  'grams': 'g',
  'gramme': 'g',
  'kg': 'kg',
  'kilo': 'kg',
  'kilos': 'kg',
  'kilogramm': 'kg',
  'kilogram': 'kg',
  'kilograms': 'kg',
  'pfund': 'Pfund',
  'packung': 'Packung',
  'packungen': 'Packungen',
  'pack': 'Pack',
  'packs': 'Packs',
  'packet': 'Packet',
  'packets': 'Packets',
  'paket': 'Paket',
  'pakete': 'Pakete',
  'dose': 'Dose',
  'dosen': 'Dosen',
  'can': 'can',
  'cans': 'cans',
  'tin': 'tin',
  'tins': 'tins',
  'flasche': 'Flasche',
  'flaschen': 'Flaschen',
  'bottle': 'bottle',
  'bottles': 'bottles',
  'becher': 'Becher',
  'glas': 'Glas',
  'glaeser': 'Gläser',
  'jar': 'jar',
  'jars': 'jars',
  'bund': 'Bund',
  'bunch': 'bunch',
  'bunches': 'bunches',
  'stueck': 'Stück',
  'piece': 'piece',
  'pieces': 'pieces',
  'tafel': 'Tafel',
  'tafeln': 'Tafeln',
  'netz': 'Netz',
  'beutel': 'Beutel',
  'bag': 'bag',
  'bags': 'bags',
  'dozen': 'dozen',
  'dutzend': 'Dutzend',
  'litro': 'l',
  'litros': 'l',
  'grammes': 'g',
  'gramo': 'g',
  'gramos': 'g',
  'kilogramme': 'kg',
  'kilogrammes': 'kg',
  'kilogramo': 'kg',
  'kilogramos': 'kg',
  'paquet': 'paquet',
  'paquets': 'paquets',
  'paquete': 'paquete',
  'paquetes': 'paquetes',
  'boite': 'boîte',
  'boites': 'boîtes',
  'lata': 'lata',
  'latas': 'latas',
  'bouteille': 'bouteille',
  'bouteilles': 'bouteilles',
  'botella': 'botella',
  'botellas': 'botellas',
  'douzaine': 'douzaine',
  'docena': 'docena',
};

// Words that add nothing when they open an item ("Bitte Milch", "noch Eier").
const _fillers = <String>{
  'bitte',
  'noch',
  'auch',
  'etwas',
  'some',
  'please',
  'more',
  'also',
};

/// Words that join a unit and a name ("2 cans of tomatoes", "deux litres de lait").
const _unitJoiners = <String>{'of', 'von', 'de'};

final _splitter = RegExp(
  r'(?<!\d),|,(?!\d)|[;\n]+|\s+(?:und|and|sowie|et|y)\s+|\s*&\s*|\s*\+\s*',
  caseSensitive: false,
);
final _gluedUnit = RegExp(r'^(\d+(?:[.,]\d+)?)([a-zA-Z]+)$');
final _numeric = RegExp(r'^(\d+(?:[.,]\d+)?)(?:x|×)?$', caseSensitive: false);
final _timesFirst = RegExp(r'^[x×](\d+)$', caseSensitive: false);

/// Items from typed or dictated text: split at commas (not a decimal comma),
/// semicolons, new lines, "und"/"and", "&" and "+". A number or number word with a
/// unit becomes the quantity ("2 Liter Milch" gives Milch, "2 l"), a bare number the
/// count ("3 Äpfel" gives Äpfel, 3). Forgiving on purpose: speech should be filed
/// imperfectly rather than not at all.
List<ParsedItem> parseShoppingText(String text, {int maxItems = 20}) {
  final items = <ParsedItem>[];
  for (final raw in text.split(_splitter)) {
    final part = raw.trim().replaceFirst(RegExp(r'[.!?]+$'), '').trim();
    if (part.isEmpty) continue;
    final item = parseShoppingItem(part);
    if (item != null) items.add(item);
    if (items.length == maxItems) break;
  }
  return items;
}

/// One item (no splitting). The amount may lead ("2 l Milch", "500g Mehl") or, if
/// nothing leads, trail ("Milch 1l", "Kartoffeln 2 kg", "Eier 6", "Joghurt 4x").
/// A leading amount wins; a trailing number is then part of the name.
ParsedItem? parseShoppingItem(String part) {
  final tokens = part.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  while (tokens.length > 1 && _fillers.contains(fold(tokens.first))) {
    tokens.removeAt(0);
  }
  if (tokens.length < 2) return _finish(tokens, null, null);
  final first = tokens.first;

  // "2l Milch", "500g Mehl": the unit glued to the number.
  final glued = _gluedUnit.firstMatch(first);
  if (glued != null && _units.containsKey(fold(glued[2]!))) {
    return _finish(
      tokens.sublist(1),
      '${glued[1]} ${_units[fold(glued[2]!)]}',
      null,
    );
  }

  // "2", "2,5", "2x", "zwei", "a".
  final numeric = _numeric.firstMatch(first);
  final String? amount = numeric != null
      ? numeric[1]
      : _numberWords.containsKey(fold(first))
      ? '${_numberWords[fold(first)]}'
      : null;
  if (amount == null) return _trailing(tokens);

  final rest = tokens.sublist(1);
  if (rest.length > 1 && _units.containsKey(fold(rest.first))) {
    final unit = _units[fold(rest.first)];
    final name = rest.sublist(1);
    if (name.length > 1 && _unitJoiners.contains(fold(name.first))) {
      name.removeAt(0);
    }
    return _finish(name, '$amount $unit', null);
  }
  return _amountOnly(rest, amount);
}

/// The amount at the end of an item that has none at the front.
ParsedItem? _trailing(List<String> tokens) {
  final last = tokens.last;
  final head = tokens.sublist(0, tokens.length - 1);

  // "Milch 1l", "Cola 1,5l".
  final glued = _gluedUnit.firstMatch(last);
  if (glued != null && _units.containsKey(fold(glued[2]!))) {
    return _finish(head, '${glued[1]} ${_units[fold(glued[2]!)]}', null);
  }

  // "Kartoffeln 2 kg".
  if (head.length > 1 &&
      _units.containsKey(fold(last)) &&
      _numeric.hasMatch(head.last) &&
      !head.last.toLowerCase().endsWith('x') &&
      !head.last.endsWith('×')) {
    return _finish(
      head.sublist(0, head.length - 1),
      '${head.last} ${_units[fold(last)]}',
      null,
    );
  }

  // "Joghurt x4".
  final timesFirst = _timesFirst.firstMatch(last);
  if (timesFirst != null) return _amountOnly(head, timesFirst[1]!);

  // "Eier 6", "Joghurt 4x", "Mehl 0,5".
  final numeric = _numeric.firstMatch(last);
  if (numeric != null) return _amountOnly(head, numeric[1]!);

  return _finish(tokens, null, null);
}

/// A number without a unit: 1 to 99 whole is a count, anything else a quantity.
ParsedItem? _amountOnly(List<String> name, String amount) {
  final n = double.parse(amount.replaceAll(',', '.'));
  return n == n.truncateToDouble() && n >= 1 && n <= 99
      ? _finish(name, null, n.toInt())
      : _finish(name, amount, null);
}

ParsedItem? _finish(List<String> tokens, String? quantity, int? count) {
  var name = tokens.join(' ').trim();
  if (name.length > 120) name = name.substring(0, 120);
  if (name.isEmpty) return null;
  return ParsedItem(
    name: name[0].toUpperCase() + name.substring(1),
    quantity: quantity,
    count: count != null && count > 1 ? count : null,
  );
}
