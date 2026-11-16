import 'package:intl/intl.dart';

/// What was typed in a price field: [valid] false for text that is no amount; [cents] null
/// for an empty field (no price).
typedef PriceInput = ({bool valid, int? cents});

/// The most a price may be, in cents: a trip's entry costing a hundred million is a typo.
const _maxCents = 100000000 * 100;

/// Reads an amount as a person writes it, in the trip's currency, into cents. "840",
/// "1249.50", "1249,50", "1'249.50" and "1.249,50" are all fine: with both separators the
/// last one is the decimal one; a single separator followed by one or two digits is the
/// decimal one; followed by exactly three digits it is a thousands separator, unless it is
/// the [locale]'s own decimal separator ("1.249" in German is 1249).
PriceInput parsePriceInput(String text, {required String locale}) {
  final s = text.trim().replaceAll(RegExp(r"[\s'\u2019\u00a0\u202f]"), '');
  if (s.isEmpty) return (valid: true, cents: null);
  if (!RegExp(r'^[0-9.,]*[0-9][0-9.,]*$').hasMatch(s)) {
    return (valid: false, cents: null);
  }

  final decimalSep = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  final dots = '.'.allMatches(s).length;
  final commas = ','.allMatches(s).length;

  String whole;
  var fraction = '';
  if (dots == 0 && commas == 0) {
    whole = s;
  } else {
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    final sep = lastDot > lastComma ? '.' : ',';
    final at = lastDot > lastComma ? lastDot : lastComma;
    final after = s.substring(at + 1);
    final before = s.substring(0, at);
    final both = dots > 0 && commas > 0;
    final sepCount = sep == '.' ? dots : commas;
    if (!both && sepCount > 1) {
      // "1.249.500": only thousands separators.
      final groups = s.split(sep);
      if (groups.skip(1).any((g) => g.length != 3)) {
        return (valid: false, cents: null);
      }
      whole = groups.join();
    } else if (!both && after.length == 3) {
      if (sep == decimalSep) return (valid: false, cents: null);
      whole = '$before$after';
    } else {
      if (after.length > 2) return (valid: false, cents: null);
      whole = before.replaceAll(RegExp('[.,]'), '');
      fraction = after;
    }
  }
  if (whole.isEmpty) whole = '0';
  if (whole.length > 10) return (valid: false, cents: null);
  final cents = int.parse(whole) * 100 + int.parse(fraction.padRight(2, '0'));
  if (cents > _maxCents) return (valid: false, cents: null);
  return (valid: true, cents: cents);
}

/// An amount for a price field to edit: whole amounts without decimals, else two, with the
/// [locale]'s decimal separator and no thousands separator.
String priceInputText(int cents, {required String locale}) {
  final symbols = NumberFormat.decimalPattern(locale).symbols;
  final whole = cents ~/ 100;
  final rest = cents % 100;
  if (rest == 0) return '$whole';
  return '$whole${symbols.DECIMAL_SEP}${rest.toString().padLeft(2, '0')}';
}
