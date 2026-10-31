import 'dart:async';

import 'package:wuselwall/features/shopping/data/starter_catalog.dart';

/// Every test starts without the starter catalogue: the bundle loads through real I/O
/// that may or may not have finished by the time a test looks at the tiles, which would
/// add suggestions to any test that adds or counts items by name. The tests of the
/// suggestions (shopping_starter_test.dart) override `starterCatalogProvider`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  starterCatalogLoader = () async => StarterCatalog.empty;
  await testMain();
}
