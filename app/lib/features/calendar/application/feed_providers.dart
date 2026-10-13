import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/calendar/data/feed_repository.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// The household's subscriptions, revoked ones included (shown greyed). Refetched on
/// a household change; feed tokens are not broadcast, so the page refreshes itself.
final feedTokensProvider = FutureProvider.autoDispose<List<FeedToken>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  return (await ref.watch(feedRepositoryProvider).tokens()).unwrap();
});
