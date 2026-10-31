import 'package:wuselwall/core/text/fold.dart';

/// The one spelling the matcher compares: folded, and everything that is not a
/// letter or digit collapsed to a single space ("WC-Papier" becomes "wc papier",
/// "Jus d'orange" becomes "jus d orange"). Dictionary words and typed text both
/// go through it, so a hyphen or an apostrophe never decides a match.
String normalizeText(String s) =>
    fold(s).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// The words of an already normalised text.
List<String> tokens(String normalized) =>
    normalized.split(' ').where((t) => t.isNotEmpty).toList();
