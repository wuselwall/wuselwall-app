import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/data/coop_handoff_store.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';

/// Whether this build can hand a list to Coop at all (specs/29): the connector needs a
/// WebView, which only the iOS and Android apps have. The web app and the tests say no
/// unless a test says otherwise.
final coopHandoffSupportedProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS),
);

/// This device's link to the Coop list; null while it is not connected. Connecting is
/// signing in once in the Coop sheet; disconnecting forgets the link and the session.
final coopHandoffProvider =
    AsyncNotifierProvider<CoopHandoffNotifier, HandoffState?>(
      CoopHandoffNotifier.new,
    );

class CoopHandoffNotifier extends AsyncNotifier<HandoffState?> {
  CoopHandoffStore get _store => ref.read(coopHandoffStoreProvider);

  @override
  Future<HandoffState?> build() => _store.read();

  /// Signed in: from now on the list screen offers "An Coop senden".
  Future<void> connect() async {
    final now = state.value ?? await _store.read() ?? const HandoffState();
    await save(now);
  }

  /// Keeps what a push left behind, also a push that stopped half-way.
  Future<void> save(HandoffState next) async {
    state = AsyncData(next);
    await _store.write(next);
  }

  /// Forgets the link and ends the Coop session on this device. The list on the Coop
  /// side stays as it is: it is the family's, in their Coop account.
  Future<void> disconnect() async {
    state = const AsyncData(null);
    await _store.clear();
    await ref.read(coopSessionClearerProvider)();
  }
}

/// Ends the Coop session: the WebView's cookies (only the Coop sheet uses a WebView in
/// this app). Nothing to clear in a build without one.
final coopSessionClearerProvider = Provider<Future<void> Function()>((ref) {
  final supported = ref.watch(coopHandoffSupportedProvider);
  return () async {
    if (supported) await WebViewCookieManager().clearCookies();
  };
});

/// Whether the list screen offers "An Coop senden" here: a build with a WebView, an
/// adult's register (never the children's or the wall), and a connected device.
final coopHandoffAvailableProvider = Provider<bool>((ref) {
  if (!ref.watch(coopHandoffSupportedProvider)) return false;
  if (ref.watch(uiRegisterProvider) != UiRegister.adult) return false;
  return ref.watch(coopHandoffProvider).value != null;
});
