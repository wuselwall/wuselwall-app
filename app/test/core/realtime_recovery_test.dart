import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/realtime/refresh_events.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

import '../support/fakes.dart';

class _Channel implements RealtimeChannel {
  late void Function(RealtimeSubscribeStatus, Object?) status;
  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic>) callback,
  }) => this;
  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) {
    status = callback!;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Client implements SupabaseClient {
  final stream = _Channel();
  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) => stream;
  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('network recovery and resume emit repeatable refresh events', (
    t,
  ) async {
    final network = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(network.close);
    var recovered = 0;
    final subscription = appRefreshEvents(connectivity: network.stream)
        .listen((_) => recovered++);
    addTearDown(subscription.cancel);
    network.add([ConnectivityResult.none]);
    network.add([ConnectivityResult.wifi]);
    network.add([ConnectivityResult.wifi]);
    await t.pump();
    expect(
      recovered,
      1,
      reason: 'an unchanged online state is not another recovery',
    );
    network.add([ConnectivityResult.none]);
    network.add([ConnectivityResult.mobile]);
    await t.pump();
    expect(recovered, 2);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(state);
    }
    await t.pump();
    expect(recovered, 3);
  });

  test(
    'subscribe, reconnect and repeated foreground recovery refetch cached data',
    () async {
      final client = _Client();
      final recoveries = StreamController<int>.broadcast();
      addTearDown(recoveries.close);
      final calendar = FakeCalendarRepository();
      final c = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(AsyncData(device())),
          supabaseClientProvider.overrideWithValue(client),
          calendarRepositoryProvider.overrideWithValue(calendar),
          appRefreshEventsProvider.overrideWith((ref) => recoveries.stream),
        ],
      );
      addTearDown(c.dispose);
      final window = occurrencesProvider((
        from: DateTime(2026, 10, 25),
        to: DateTime(2026, 10, 25),
      ));
      c.listen(window, (_, _) {});
      final initial = await c.read(window.future);
      client.stream.status(RealtimeSubscribeStatus.subscribed, null);
      await pumpEventQueue();
      final subscribed = c.read(window).requireValue;
      expect(subscribed, isNot(same(initial)));
      client.stream.status(RealtimeSubscribeStatus.closed, null);
      client.stream.status(RealtimeSubscribeStatus.subscribed, null);
      await pumpEventQueue();
      final reconnected = c.read(window).requireValue;
      expect(reconnected, isNot(same(subscribed)));
      for (final revision in [1, 2]) {
        final previous = c.read(window).requireValue;
        recoveries.add(revision);
        await pumpEventQueue();
        expect(c.read(window).requireValue, isNot(same(previous)));
      }
    },
  );
}
