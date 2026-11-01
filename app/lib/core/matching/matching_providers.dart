import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/matching/dictionary.dart';
import 'package:wuselwall/core/matching/dictionary_loader.dart';
import 'package:wuselwall/core/matching/matcher.dart';

/// The bundled dictionaries, read once from the asset (specs/29).
final matchDictionariesProvider = FutureProvider<MatchDictionaries>(
  (ref) => loadMatchDictionaries(),
);

/// The matcher of the `shopping` domain: null while the dictionary loads, or when it
/// holds no such domain. Callers treat null as "no suggestion", never as an error.
final shoppingMatcherProvider = Provider<Matcher?>((ref) {
  final dictionary = ref
      .watch(matchDictionariesProvider)
      .value
      ?.byDomain['shopping'];
  return dictionary == null ? null : Matcher(dictionary);
});
