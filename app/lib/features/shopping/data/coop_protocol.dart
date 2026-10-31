import 'package:wuselwall/core/text/fold.dart';

/// How coop.ch's own list pages talk to coop.ch (specs/29, "What was found"): undocumented,
/// learned from the website, and so the one file to fix when coop.ch changes. Every
/// request runs inside a signed-in WebView with the page's own cookies; nothing here
/// holds a credential.

const coopOrigin = 'https://www.coop.ch';
const coopHost = 'www.coop.ch';

/// The name of the list the pushes create and fill on the Coop side.
const coopListName = 'WuselWall';

/// The site's languages; any other app language reads it in English.
String coopLanguage(String appLanguageCode) => switch (appLanguageCode) {
  'de' || 'fr' || 'it' || 'en' => appLanguageCode,
  _ => 'en',
};

/// The list page. Opened without a session it goes to the Supercard ID sign-in and
/// back (silently when the Supercard session still lives).
Uri coopListPage(String lang) => Uri.parse('$coopOrigin/$lang/shopping-list');

/// The sign-in page, for when the list page did not end signed in.
Uri coopLoginPage(String lang) => Uri.parse('$coopOrigin/$lang/login');

String coopCreateListPath(String lang) =>
    '/$lang/shopping-list/overview/create';

/// The active list's panel: JSON with `panelHtml`, the list that is active now.
String coopPanelPath(String lang) => '/$lang/my-lists/my-shoppinglist';

String coopAddGenericPath(String lang) =>
    '/$lang/shopping-list/add-product/generic';

String coopRemoveEntryPath(String lang, String entryId) =>
    '/$lang/shopping-list/remove-entry/${Uri.encodeComponent(entryId)}';

String coopGenericSuggestionsPath(String lang, String name) =>
    '/$lang/shopping-list/searchsuggestion/result/genericproducts'
    '?name=${Uri.encodeQueryComponent(name)}';

/// The cookie that names the active list. The site sets it itself from its scripts; the
/// add call puts the item on the list it names.
const coopActiveListCookie = 'activeShoppingListId';

/// The form field the site expects on every POST, read from `ACC.config.CSRFToken`.
const coopCsrfField = 'CSRFToken';

final _listIdAttr = RegExp(r'data-shopping-list-id="([^"]+)"');
final _entryFromHref = RegExp(r'/update-modal/([^/?#"]+)');
final _numericEntity = RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);');

/// [html] with the character references coop.ch writes into attributes decoded.
String decodeHtmlAttributes(String html) => html
    .replaceAllMapped(_numericEntity, (m) {
      final code = m.group(1)!;
      final value = code.startsWith('x')
          ? int.tryParse(code.substring(1), radix: 16)
          : int.tryParse(code);
      return value == null ? m.group(0)! : String.fromCharCode(value);
    })
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&');

String? _firstListId(Object? html) {
  if (html is! String) return null;
  return _listIdAttr.firstMatch(decodeHtmlAttributes(html))?.group(1);
}

/// The id of the list a create call made: the list's HTML in `shoppingListHtml`.
String? listIdFromCreate(Object? json) {
  if (json is! Map) return null;
  return _firstListId(json['shoppingListHtml']) ??
      _firstListId(json['shoppingPanel']);
}

/// The id of the active list in the panel answer.
String? activeListIdFromPanel(Object? json) {
  if (json is! Map) return null;
  return _firstListId(json['panelHtml']);
}

/// The entry an add call made: `success` and the snackbar's "Refine" link, which ends in
/// the entry id. Null when the answer says anything else.
String? entryIdFromAdd(Object? json) {
  if (json is! Map || json['success'] != true) return null;
  final snackbar = json['snackbar'];
  if (snackbar is! Map) return null;
  final attrs = snackbar['actionAttrs'];
  if (attrs is! Map) return null;
  final href = attrs['href'];
  if (href is! String) return null;
  return _entryFromHref.firstMatch(decodeHtmlAttributes(href))?.group(1);
}

/// Whether a remove call took the entry off. The answer's own `success` is false even
/// then; the entry's part carries it.
bool entryRemoved(Object? json) {
  if (json is! Map) return false;
  if (json['success'] == true) return true;
  final entry = json['shoppingPanelEntry'];
  return entry is Map && entry['success'] == true;
}

/// The generic product whose name is [name] (ignoring case and accents), for its
/// picture on the Coop list; null when none matches exactly.
String? genericProductCode(Object? json, String name) {
  if (json is! Map) return null;
  final products = json['products'];
  if (products is! List) return null;
  final wanted = fold(name);
  for (final product in products) {
    if (product is! Map) continue;
    final code = product['code'];
    final names = [product['name'], product['title']].whereType<String>();
    if (code != null && names.any((n) => fold(n) == wanted)) {
      return code.toString();
    }
  }
  return null;
}

/// The bridge the WebView runs: `window.__wwCoop(request)` answers on the
/// `WuselWallCoop` channel with the request's `id`. It defines itself once per page.
///
/// - `page`: whether the page is signed in (the account menu or the sign-out link the
///   site draws only then) and the CSRF token.
/// - `cookie`: sets the active-list cookie the way the site's own script does.
/// - `fetch`: a same-origin request with the page's cookies; the answer's status, final
///   URL and text.
const coopBridgeScript = r'''
(function () {
  if (window.__wwCoop) return;
  function answer(reply) {
    WuselWallCoop.postMessage(JSON.stringify(reply));
  }
  window.__wwCoop = async function (req) {
    var reply = { id: req.id };
    try {
      if (req.op === 'page') {
        reply.url = location.href;
        reply.csrf = (window.ACC && ACC.config && ACC.config.CSRFToken) || null;
        reply.signedIn = !!document.querySelector('[data-my-account-menu]') ||
          !!document.querySelector('a[href$="/logout"]');
      } else if (req.op === 'cookie') {
        document.cookie = req.name + '=' + encodeURIComponent(req.value) +
          '; path=/; max-age=31536000; samesite=lax; secure';
        reply.ok = true;
      } else {
        var init = {
          method: req.method,
          credentials: 'include',
          headers: { 'X-Requested-With': 'XMLHttpRequest', 'Accept': '*/*' }
        };
        if (req.form) {
          init.headers['Content-Type'] =
            'application/x-www-form-urlencoded; charset=UTF-8';
          init.body = new URLSearchParams(req.form).toString();
        }
        var response = await fetch(req.path, init);
        reply.status = response.status;
        reply.url = response.url;
        reply.body = await response.text();
      }
    } catch (e) {
      reply.error = String(e);
    }
    answer(reply);
  };
})();
''';
