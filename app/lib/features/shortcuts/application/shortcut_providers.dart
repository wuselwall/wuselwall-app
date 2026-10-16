import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shortcuts/data/shortcut_repository.dart';

/// The household's shortcut keys, revoked ones included (shown greyed). Refetched on a
/// household change; keys are not broadcast, so the page refreshes itself.
final shortcutTokensProvider = FutureProvider.autoDispose<List<ShortcutToken>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  return (await ref.watch(shortcutRepositoryProvider).tokens()).unwrap();
});
