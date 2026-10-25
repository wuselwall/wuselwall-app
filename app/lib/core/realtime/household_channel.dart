import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/realtime/refresh_events.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// "Something in [topic] changed — refetch." Database triggers broadcast these on the
/// household's private channel; the payload deliberately carries no data, so a stale or
/// replayed message can never show wrong information (ADR-010: live updates).
class Invalidation {
  /// Not `const`, on purpose: Riverpod tells a listener of the stream only when the value
  /// differs from the last one, and two identical canonical constants (a rejoin after a
  /// rejoin) would be swallowed. Every event gets its own [seq].
  Invalidation(this.topic) : seq = _issued++;

  /// A subscription or foreground recovery: any cached module may have missed data.
  Invalidation.all() : this('*');

  static int _issued = 0;

  bool affects(String topic) => this.topic == '*' || this.topic == topic;

  /// A module name such as `shopping` or `tasks`.
  final String topic;

  /// Which event this is; no two events share one.
  final int seq;

  @override
  bool operator ==(Object other) => other is Invalidation && other.seq == seq;

  @override
  int get hashCode => seq.hashCode;
}

/// Joins the private channel `household:<id>` and exposes its invalidations.
final householdInvalidationsProvider =
    StreamProvider.family<Invalidation, String>((ref, householdId) {
      final client = ref.watch(supabaseClientProvider);
      final controller = StreamController<Invalidation>();
      void emit(Invalidation event) {
        if (!controller.isClosed) controller.add(event);
      }

      ref.listen(appRefreshEventsProvider, (previous, next) {
        if (next.hasValue && next.value != previous?.value) {
          emit(Invalidation.all());
        }
      });
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
              if (topic is String) emit(Invalidation(topic));
            },
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              emit(Invalidation.all());
            }
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
  Set<String> also = const {},
}) {
  ref.listen(householdInvalidationsProvider(householdId), (_, next) {
    final event = next.value;
    if (event != null && (event.affects(topic) || also.any(event.affects))) {
      ref.invalidateSelf();
    }
  });
}
