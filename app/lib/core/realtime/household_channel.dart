import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// "Something in [topic] changed — refetch." Database triggers broadcast these on the
/// household's private channel; the payload deliberately carries no data, so a stale or
/// replayed message can never show wrong information (ADR-010: live updates).
class Invalidation {
  const Invalidation(this.topic);

  /// A module name such as `shopping` or `tasks`.
  final String topic;
}

/// Joins the private channel `household:<id>` and exposes its invalidations.
final householdInvalidationsProvider =
    StreamProvider.family<Invalidation, String>((ref, householdId) {
      final client = ref.watch(supabaseClientProvider);
      final controller = StreamController<Invalidation>();

      final channel = client
          .channel(
            'household:$householdId',
            opts: const RealtimeChannelConfig(private: true),
          )
          .onBroadcast(
            event: 'invalidate',
            callback: (message) {
              // supabase_flutter hands over the whole envelope:
              // {type, event, payload: {topic, ...}, meta}.
              final body = message['payload'];
              final topic = body is Map<String, dynamic> ? body['topic'] : null;
              if (topic is String) controller.add(Invalidation(topic));
            },
          )
          .subscribe((status, error) {
            if (error != null) {
              logError('Realtime channel $status', error: error);
            }
          });

      ref.onDispose(() {
        unawaited(client.removeChannel(channel));
        unawaited(controller.close());
      });
      return controller.stream;
    });

/// Call inside a provider body: re-runs that provider whenever [topic] is invalidated
/// on the household's channel.
///
/// ```dart
/// final shoppingItemsProvider = FutureProvider.autoDispose((ref) {
///   refreshOnInvalidation(ref, householdId: id, topic: 'shopping');
///   ...
/// });
/// ```
void refreshOnInvalidation(
  Ref ref, {
  required String householdId,
  required String topic,
}) {
  ref.listen(householdInvalidationsProvider(householdId), (_, next) {
    final event = next.value;
    if (event != null && event.topic == topic) ref.invalidateSelf();
  });
}
