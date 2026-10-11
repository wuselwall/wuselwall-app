import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has any network at all. This says nothing about whether the
/// backend is reachable — that is what `api.health()` is for — but it lets screens say
/// "offline" immediately instead of waiting for a request to time out.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_online);
});

bool _online(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
