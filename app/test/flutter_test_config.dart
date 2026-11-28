import 'dart:async';

import 'package:wuselwall/core/matching/dictionary.dart';
import 'package:wuselwall/core/matching/matching_providers.dart';
import 'package:wuselwall/features/shopping/data/starter_catalog.dart';

/// Every test starts without the starter catalogue: the bundle loads through real I/O
/// that may or may not have finished by the time a test looks at the tiles, which would
/// add suggestions to any test that adds or counts items by name. The tests of the
/// suggestions (shopping_starter_test.dart) override `starterCatalogProvider`.
///
/// Likewise without the matching dictionaries: a typed event or task title proposes no
/// picture unless a test overrides `eventsMatcherProvider` or `tasksMatcherProvider`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  starterCatalogLoader = () async => StarterCatalog.empty;
  matchDictionariesLoader = () async => MatchDictionaries(const {});
  await testMain();
}
