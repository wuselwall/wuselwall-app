import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRefreshEventsProvider = StreamProvider<int>((ref) {
  var revision = 0;
  return appRefreshEvents().map((_) => ++revision);
});

/// A chance to recover changes missed while suspended or disconnected. The first
/// successful Realtime subscription separately closes the fetch/subscribe gap.
Stream<void> appRefreshEvents({
  Stream<List<ConnectivityResult>>? connectivity,
}) {
  late StreamController<void> controller;
  AppLifecycleListener? lifecycle;
  StreamSubscription<List<ConnectivityResult>>? network;
  bool? online;
  controller = StreamController<void>(
    onListen: () {
      lifecycle = AppLifecycleListener(onResume: () => controller.add(null));
      network = (connectivity ?? Connectivity().onConnectivityChanged).listen((
        results,
      ) {
        final next = results.any((r) => r != ConnectivityResult.none);
        if (next && online != true) controller.add(null);
        online = next;
      }, onError: controller.addError);
    },
    onCancel: () async {
      lifecycle?.dispose();
      await network?.cancel();
    },
  );
  return controller.stream;
}
