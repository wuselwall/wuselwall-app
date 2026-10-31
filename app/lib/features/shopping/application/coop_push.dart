import 'dart:async';
import 'dart:convert';

import 'package:wuselwall/features/shopping/data/coop_protocol.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';

/// The page a request runs from: whether it is signed in, and its CSRF token.
class CoopPage {
  const CoopPage({required this.signedIn, this.csrf, this.url});

  final bool signedIn;
  final String? csrf;
  final String? url;
}

/// One answer from coop.ch. [json] is the decoded body when it was JSON.
class CoopReply {
  const CoopReply({required this.status, this.url, this.body, this.error});

  final int status;
  final String? url;
  final String? body;

  /// The request did not complete (a network failure, a redirect the page may not
  /// follow).
  final String? error;

  Object? get json {
    final text = body;
    if (text == null || text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// coop.ch sent the request to its sign-in instead of answering it.
  bool get signedOut {
    if (error != null || status == 401 || status == 403) return true;
    final host = url == null ? null : Uri.tryParse(url!)?.host;
    return host != null && host.isNotEmpty && host != coopHost;
  }
}

/// How the push reaches coop.ch: the signed-in WebView in the app, a fake in tests.
abstract interface class CoopTransport {
  Future<CoopPage> page();

  Future<CoopReply> get(String path);

  Future<CoopReply> post(String path, Map<String, String> form);

  Future<void> setCookie(String name, String value);
}

/// The session ended (or never began): sign in and push again.
class CoopSignedOut implements Exception {
  const CoopSignedOut();
}

/// coop.ch answered in a way this app does not understand: the site has changed.
class CoopUnexpected implements Exception {
  const CoopUnexpected(this.step);

  final String step;

  @override
  String toString() => 'CoopUnexpected($step)';
}

/// One push (specs/29, "Mechanism"): make the list [coopListName] on coop.ch equal to
/// [items], touching only the entries this device made. [state] is the device's link
/// before; [CoopPush.state] is the link after, also when the push stopped half-way, so
/// what did go across is remembered.
class CoopPush {
  CoopPush({
    required this.transport,
    required this.lang,
    required this._state,
    this.spacing = const Duration(milliseconds: 150),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CoopTransport transport;
  final String lang;

  /// The pause between two requests: a person clicking, not a script hammering.
  final Duration spacing;
  final DateTime Function() _clock;

  HandoffState _state;
  HandoffState get state => _state;

  late String _csrf;
  bool _first = true;

  Future<void> _pace() async {
    if (_first) {
      _first = false;
      return;
    }
    if (spacing > Duration.zero) await Future<void>.delayed(spacing);
  }

  Future<CoopReply> _get(String path) async {
    await _pace();
    final reply = await transport.get(path);
    if (reply.signedOut) throw const CoopSignedOut();
    return reply;
  }

  Future<CoopReply> _post(String path, Map<String, String> form) async {
    await _pace();
    final reply = await transport.post(path, {...form, coopCsrfField: _csrf});
    if (reply.signedOut) throw const CoopSignedOut();
    return reply;
  }

  /// The list to fill: the remembered one while it still exists, else a new one.
  Future<String> _list() async {
    final known = _state.listId;
    if (known != null) {
      await transport.setCookie(coopActiveListCookie, known);
      final panel = await _get(coopPanelPath(lang));
      if (activeListIdFromPanel(panel.json) == known) return known;
      // Deleted on the Coop side: its entries went with it.
      _state = _state.copyWith(clearList: true, entries: const {});
    }
    final created = await _post(coopCreateListPath(lang), {
      'listName': coopListName,
    });
    final id = listIdFromCreate(created.json);
    if (id == null) throw const CoopUnexpected('create');
    await transport.setCookie(coopActiveListCookie, id);
    _state = _state.copyWith(listId: id, entries: const {});
    return id;
  }

  Future<HandoffResult> run(List<HandoffItem> items) async {
    final page = await transport.page();
    final csrf = page.csrf;
    if (!page.signedIn || csrf == null || csrf.isEmpty) {
      throw const CoopSignedOut();
    }
    _csrf = csrf;
    await _list();

    final plan = planHandoff(items, _state.entries);
    final entries = {..._state.entries};
    for (final MapEntry(key: entryId, value: itemId) in plan.remove.entries) {
      // Whatever the answer, the entry is no longer this device's: one already taken
      // off by hand answers "not found", and a retry would never succeed.
      await _post(coopRemoveEntryPath(lang, entryId), const {});
      entries.remove(itemId);
      _state = _state.copyWith(entries: {...entries});
    }

    var failed = 0;
    for (final item in plan.add) {
      final suggestions = await _get(
        coopGenericSuggestionsPath(lang, item.name),
      );
      final code = genericProductCode(suggestions.json, item.name);
      final added = await _post(coopAddGenericPath(lang), {
        'productName': item.label,
        'productId': ?code,
      });
      final entryId = entryIdFromAdd(added.json);
      if (entryId == null) {
        failed++;
        continue;
      }
      entries[item.id] = HandoffEntry(entryId: entryId, label: item.label);
      _state = _state.copyWith(entries: {...entries});
    }

    _state = _state.copyWith(
      lastPushAt: _clock(),
      lastPushCount: entries.length,
    );
    if (failed == plan.add.length && plan.add.isNotEmpty) {
      throw const CoopUnexpected('add');
    }
    return HandoffResult(
      sent: entries.length,
      total: items.length,
      failed: failed,
    );
  }
}
