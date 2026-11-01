import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/features/shopping/application/coop_handoff_providers.dart';
import 'package:wuselwall/features/shopping/application/coop_push.dart';
import 'package:wuselwall/features/shopping/data/coop_handoff_store.dart';
import 'package:wuselwall/features/shopping/data/coop_protocol.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';

/// How the Coop sheet ended.
sealed class CoopOutcome {
  const CoopOutcome();
}

/// Signed in (the settings page's "Bei Coop anmelden").
final class CoopConnected extends CoopOutcome {
  const CoopConnected();
}

final class CoopPushed extends CoopOutcome {
  const CoopPushed(this.result);

  final HandoffResult result;
}

/// coop.ch was not reachable or answered in a way the app does not understand.
final class CoopFailed extends CoopOutcome {
  const CoopFailed();
}

/// Opens the Coop sheet: sign in only when [items] is null, else push them. Null when
/// the person closed it. A provider, so widget tests replace the WebView.
typedef CoopSheetLauncher = Future<CoopOutcome?> Function(
  BuildContext context, {
  List<HandoffItem>? items,
});

final coopSheetLauncherProvider = Provider<CoopSheetLauncher>(
  (ref) =>
      (context, {items}) => showModalBottomSheet<CoopOutcome>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => CoopSheet(items: items),
      ),
);

/// The snackbar line for [outcome].
String coopOutcomeMessage(AppLocalizations l10n, CoopOutcome outcome) =>
    switch (outcome) {
      CoopConnected() => l10n.coopSignedIn,
      CoopPushed(:final result) when result.complete => l10n.coopPushed(
        result.sent,
        coopListName,
      ),
      CoopPushed(:final result) => l10n.coopPushedPartly(
        result.sent,
        result.total,
      ),
      CoopFailed() => l10n.coopPushFailed,
    };

enum _Phase { loading, signIn, pushing }

/// coop.ch in a WebView (specs/30, "Mechanism"): the list page, which signs in through
/// the Supercard ID by itself while that session lives. When it does not, the sheet
/// shows Coop's own sign-in page; otherwise a progress panel covers the page while the
/// requests run from it, with its own cookies.
class CoopSheet extends ConsumerStatefulWidget {
  const CoopSheet({super.key, this.items});

  final List<HandoffItem>? items;

  @override
  ConsumerState<CoopSheet> createState() => _CoopSheetState();
}

class _CoopSheetState extends ConsumerState<CoopSheet> {
  late final WebViewController _controller;
  late final WebViewCoopTransport _transport;
  String? _lang;
  var _phase = _Phase.loading;

  /// The sign-in page has been opened once: a second page without a session is the
  /// person in the middle of signing in, not a reason to open it again.
  var _loginOpened = false;
  var _checking = false;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _transport = WebViewCoopTransport(_controller);
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      _controller.addJavaScriptChannel(
        WebViewCoopTransport.channel,
        onMessageReceived: _transport.onMessage,
      ),
    );
    unawaited(
      _controller.setNavigationDelegate(
        NavigationDelegate(
          // Only https: the sign-in may pass through Supercard's and its captcha's
          // hosts, but never a plain-text page.
          onNavigationRequest: (request) =>
              Uri.tryParse(request.url)?.scheme == 'https'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (url) => unawaited(_onPage(url)),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lang != null) return;
    final lang = coopLanguage(Localizations.localeOf(context).languageCode);
    _lang = lang;
    unawaited(_controller.loadRequest(coopListPage(lang)));
  }

  Future<void> _onPage(String url) async {
    if (_done || _checking || !mounted) return;
    if (Uri.tryParse(url)?.host != coopHost) {
      // Supercard's sign-in, or a captcha: the person's turn.
      setState(() => _phase = _Phase.signIn);
      return;
    }
    _checking = true;
    try {
      final page = await _transport.page();
      if (!mounted || _done) return;
      if (page.signedIn) {
        await _signedIn();
      } else if (!_loginOpened) {
        _loginOpened = true;
        await _controller.loadRequest(coopLoginPage(_lang!));
      } else {
        setState(() => _phase = _Phase.signIn);
      }
    } on Object catch (error, stack) {
      logError('Reading the Coop page failed', error: error, stackTrace: stack);
      _finish(const CoopFailed());
    } finally {
      _checking = false;
    }
  }

  Future<void> _signedIn() async {
    final notifier = ref.read(coopHandoffProvider.notifier);
    final items = widget.items;
    if (items == null) {
      await notifier.connect();
      _finish(const CoopConnected());
      return;
    }
    setState(() => _phase = _Phase.pushing);
    final before =
        ref.read(coopHandoffProvider).value ??
        await ref.read(coopHandoffStoreProvider).read() ??
        const HandoffState();
    final push = CoopPush(transport: _transport, lang: _lang!, state: before);
    CoopOutcome outcome;
    try {
      outcome = CoopPushed(await push.run(items));
    } on CoopSignedOut {
      await notifier.save(push.state);
      if (!mounted) return;
      // The session ended between the check and the push: sign in, then it runs again.
      setState(() => _phase = _Phase.signIn);
      _loginOpened = true;
      await _controller.loadRequest(coopLoginPage(_lang!));
      return;
    } on Object catch (error, stack) {
      logError('Pushing to Coop failed', error: error, stackTrace: stack);
      outcome = const CoopFailed();
    }
    await notifier.save(push.state);
    _finish(outcome);
  }

  void _finish(CoopOutcome outcome) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              0,
              Tokens.space2,
              Tokens.space2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.coopTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.signIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                0,
                Tokens.space4,
                Tokens.space2,
              ),
              child: Text(l10n.coopSheetSignInHint),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: WebViewWidget(controller: _controller)),
                if (_phase != _Phase.signIn)
                  Positioned.fill(
                    child: ColoredBox(
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: Tokens.space4),
                            Text(
                              _phase == _Phase.pushing
                                  ? l10n.coopSheetPushing
                                  : l10n.coopSheetChecking,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [CoopTransport] through the page loaded in [_controller]: each request runs as the
/// page's own `fetch`, with its cookies, and answers on a JavaScript channel.
class WebViewCoopTransport implements CoopTransport {
  WebViewCoopTransport(this._controller);

  static const channel = 'WuselWallCoop';
  static const timeout = Duration(seconds: 20);

  final WebViewController _controller;
  final _waiting = <int, Completer<Map<String, dynamic>>>{};
  var _next = 0;

  void onMessage(JavaScriptMessage message) {
    final Object? data;
    try {
      data = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (data is! Map) return;
    final id = data['id'];
    if (id is! int) return;
    _waiting.remove(id)?.complete(data.cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> request) async {
    final id = _next++;
    final answer = Completer<Map<String, dynamic>>();
    _waiting[id] = answer;
    try {
      // Every page load drops the bridge; defining it again is a no-op otherwise.
      await _controller.runJavaScript(coopBridgeScript);
      await _controller.runJavaScript(
        'window.__wwCoop(${jsonEncode({...request, 'id': id})});',
      );
      return await answer.future.timeout(timeout);
    } finally {
      _waiting.remove(id);
    }
  }

  CoopReply _reply(Map<String, dynamic> r) => CoopReply(
    status: (r['status'] as num?)?.toInt() ?? 0,
    url: r['url'] as String?,
    body: r['body'] as String?,
    error: r['error'] as String?,
  );

  @override
  Future<CoopPage> page() async {
    final r = await _call({'op': 'page'});
    return CoopPage(
      signedIn: r['signedIn'] == true,
      csrf: r['csrf'] as String?,
      url: r['url'] as String?,
    );
  }

  @override
  Future<CoopReply> get(String path) async =>
      _reply(await _call({'op': 'fetch', 'method': 'GET', 'path': path}));

  @override
  Future<CoopReply> post(String path, Map<String, String> form) async => _reply(
    await _call({'op': 'fetch', 'method': 'POST', 'path': path, 'form': form}),
  );

  @override
  Future<void> setCookie(String name, String value) async {
    await _call({'op': 'cookie', 'name': name, 'value': value});
  }
}
