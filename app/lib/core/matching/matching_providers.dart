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

/// The matcher of the `events` domain (specs/29 feature 3): an event title to its
/// picture. Null while the dictionary loads.
final eventsMatcherProvider = Provider<Matcher?>((ref) {
  final dictionary = ref
      .watch(matchDictionariesProvider)
      .value
      ?.byDomain['events'];
  return dictionary == null ? null : Matcher(dictionary);
});

/// The matcher of the `tasks` domain: a chore's title to its picture. Null while the
/// dictionary loads.
final tasksMatcherProvider = Provider<Matcher?>((ref) {
  final dictionary = ref
      .watch(matchDictionariesProvider)
      .value
      ?.byDomain['tasks'];
  return dictionary == null ? null : Matcher(dictionary);
});
