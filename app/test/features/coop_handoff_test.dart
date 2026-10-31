import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/shopping/application/coop_push.dart';
import 'package:wuselwall/features/shopping/data/coop_handoff_store.dart';
import 'package:wuselwall/features/shopping/data/coop_protocol.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

ShoppingItem _item(
  String id,
  String name, {
  int count = 1,
  String? note,
  bool checked = false,
}) => ShoppingItem(
  id: id,
  name: name,
  quantity: note,
  checked: checked,
  createdAt: DateTime(2026, 10, 31),
  count: count,
);

HandoffItem _h(String id, String name, [String? label]) =>
    HandoffItem(id: id, name: name, label: label ?? name);

/// coop.ch as far as the push sees it: lists of entries, the active-list cookie, a
/// session, and answers shaped like the site's (specs/29, "What was found").
class FakeCoop implements CoopTransport {
  FakeCoop({this.signedIn = true, this.generic = const {}});

  bool signedIn;

  /// Generic catalogue: name → code.
  final Map<String, String> generic;

  final lists = <String, Map<String, String>>{};
  final requests = <String>[];
  final posted = <Map<String, String>>[];
  String? active;
  var _ids = 0;

  /// Names whose add the site refuses.
  final refuse = <String>{};

  /// The session ends after this many requests.
  int? expireAfter;

  static const csrf = 'token-1';

  String _id(String prefix) => '$prefix-${(++_ids).toString().padLeft(4, '0')}';

  CoopReply _json(Object body, {int status = 200}) =>
      CoopReply(status: status, url: '$coopOrigin/x', body: jsonEncode(body));

  bool get _expired =>
      expireAfter != null && requests.length > expireAfter! || !signedIn;

  CoopReply get _toLogin => const CoopReply(
    status: 200,
    url: 'https://login.supercard.ch/cas/login',
    body: '<html></html>',
  );

  @override
  Future<CoopPage> page() async =>
      CoopPage(signedIn: signedIn, csrf: signedIn ? csrf : null);

  @override
  Future<void> setCookie(String name, String value) async {
    expect(name, coopActiveListCookie);
    active = value;
  }

  @override
  Future<CoopReply> get(String path) async {
    requests.add('GET $path');
    if (_expired) return _toLogin;
    if (path == coopPanelPath('de')) {
      final id = lists.containsKey(active) ? active : lists.keys.firstOrNull;
      return _json({
        'panelHtml': id == null
            ? '<div data-shopping-list-empty-message></div>'
            : '<div class="shoppingList" data-shopping-list="" '
                  'data-shopping-list-id="$id"></div>',
      });
    }
    if (path.startsWith(
      '/de/shopping-list/searchsuggestion/result/genericproducts',
    )) {
      final name = Uri.parse(path).queryParameters['name']!;
      return _json({
        'success': true,
        'products': [
          for (final MapEntry(:key, :value) in generic.entries)
            if (key.toLowerCase().startsWith(name.toLowerCase()))
              {'code': value, 'name': key, 'title': key},
        ],
      });
    }
    return const CoopReply(status: 404, url: '$coopOrigin/404');
  }

  @override
  Future<CoopReply> post(String path, Map<String, String> form) async {
    requests.add('POST $path');
    posted.add(form);
    if (_expired) return _toLogin;
    expect(form[coopCsrfField], csrf);
    if (path == coopCreateListPath('de')) {
      final id = _id('LIST');
      lists[id] = {};
      return _json({
        'shoppingListHtml':
            '<div data-shopping-list data-shopping-list-id="$id">'
            '<h2 data-shopping-list-name>${form['listName']}</h2></div>',
      });
    }
    if (path == coopAddGenericPath('de')) {
      final name = form['productName']!;
      if (refuse.contains(name)) return _json({'success': false});
      final list = lists[active];
      if (list == null) return _json({'success': false});
      final entry = _id('ENTRY');
      list[entry] = name;
      return _json({
        'success': true,
        'snackbar': {
          'text': "'$name' added",
          'actionAttrs': {
            'href': '/de/shopping-list/generic/update-modal/$entry',
            'data-modal': true,
          },
        },
        'shoppingPanel': '<li data-shoppinglist--entry-id="$entry"></li>',
      });
    }
    if (path.startsWith('/de/shopping-list/remove-entry/')) {
      final entry = path.split('/').last;
      final found = lists[active]?.remove(entry) != null;
      return _json({
        'success': false,
        'shoppingPanelEntry': {'success': found, 'html': '<li></li>'},
      });
    }
    return const CoopReply(status: 404, url: '$coopOrigin/404');
  }

  List<String> get shown => lists[active]?.values.toList() ?? const [];
}

Future<(HandoffResult, HandoffState)> _push(
  FakeCoop coop,
  List<HandoffItem> items, [
  HandoffState state = const HandoffState(),
]) async {
  final push = CoopPush(
    transport: coop,
    lang: 'de',
    state: state,
    spacing: Duration.zero,
    clock: () => DateTime.utc(2026, 10, 31, 12),
  );
  final result = await push.run(items);
  return (result, push.state);
}

void main() {
  group('labels', () {
    test('a single item is its name', () {
      expect(handoffLabel(_item('1', ' Milch ')), 'Milch');
    });

    test('the count when above one, the note in brackets', () {
      expect(
        handoffLabel(_item('1', 'Milch', count: 2, note: 'Bio')),
        '2× Milch (Bio)',
      );
    });

    test('a long label is cut with an ellipsis', () {
      final label = handoffLabel(_item('1', 'A' * 120));
      expect(label.length, handoffLabelMax);
      expect(label, endsWith('…'));
    });

    test('ticked and empty items stay behind', () {
      final items = handoffItems([
        _item('1', 'Milch'),
        _item('2', 'Brot', checked: true),
        _item('3', '  '),
      ]);
      expect(items.map((i) => i.id), ['1']);
    });
  });

  group('the plan', () {
    test('adds what has no entry, keeps what matches', () {
      final plan = planHandoff(
        [_h('1', 'Milch'), _h('2', 'Brot')],
        {'1': const HandoffEntry(entryId: 'E1', label: 'Milch')},
      );
      expect(plan.keep.keys, ['1']);
      expect(plan.add.map((i) => i.id), ['2']);
      expect(plan.remove, isEmpty);
    });

    test('removes the entries of items gone or changed', () {
      final plan = planHandoff(
        [_h('1', 'Milch', '2× Milch')],
        {
          '1': const HandoffEntry(entryId: 'E1', label: 'Milch'),
          '9': const HandoffEntry(entryId: 'E9', label: 'Brot'),
        },
      );
      expect(plan.remove, {'E1': '1', 'E9': '9'});
      expect(plan.add.single.label, '2× Milch');
      expect(plan.keep, isEmpty);
    });

    test('nothing to do when both sides agree', () {
      final plan = planHandoff(
        [_h('1', 'Milch')],
        {'1': const HandoffEntry(entryId: 'E1', label: 'Milch')},
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  test('the link survives the store', () async {
    final store = MemoryCoopHandoffStore();
    final state = HandoffState(
      listId: 'L',
      entries: const {'1': HandoffEntry(entryId: 'E1', label: 'Milch')},
      lastPushAt: DateTime.utc(2026, 10, 31),
      lastPushCount: 1,
    );
    final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
    final back = HandoffState.fromJson(json);
    await store.write(back);
    final read = (await store.read())!;
    expect(read.listId, 'L');
    expect(read.entries['1']!.entryId, 'E1');
    expect(read.entries['1']!.label, 'Milch');
    expect(read.lastPushAt, DateTime.utc(2026, 10, 31));
    expect(read.lastPushCount, 1);
  });

  group("reading coop.ch's answers", () {
    test('the new list id from the create answer', () {
      expect(
        listIdFromCreate({
          'shoppingListHtml': '<div class="x" data-shopping-list data-shopping-list-id="AB&#x2d;12"></div>',
        }),
        'AB-12',
      );
      expect(listIdFromCreate({'success': true}), isNull);
      expect(listIdFromCreate('nope'), isNull);
    });

    test('the entry id from the snackbar link of an add', () {
      expect(
        entryIdFromAdd({
          'success': true,
          'snackbar': {
            'actionAttrs': {
              'href': '/en/shopping-list/generic/update-modal/B0E7-4B46',
            },
          },
        }),
        'B0E7-4B46',
      );
      expect(entryIdFromAdd({'success': false}), isNull);
      expect(entryIdFromAdd({'success': true}), isNull);
    });

    test('a remove counts by the entry part, not the top-level success', () {
      expect(
        entryRemoved({
          'success': false,
          'shoppingPanelEntry': {'success': true},
        }),
        isTrue,
      );
      expect(entryRemoved({'success': false}), isFalse);
    });

    test('the active list of the panel', () {
      expect(
        activeListIdFromPanel({
          'panelHtml': '<div data-shopping-list-id="L1"></div>',
        }),
        'L1',
      );
      expect(activeListIdFromPanel({'panelHtml': '<div></div>'}), isNull);
    });

    test('a generic product only on an exact name', () {
      final json = {
        'products': [
          {'code': '10', 'name': 'Bananas', 'title': 'Bananas'},
          {'code': 11, 'name': 'Banana bread'},
        ],
      };
      expect(genericProductCode(json, 'bananas'), '10');
      expect(genericProductCode(json, 'Banana bread'), '11');
      expect(genericProductCode(json, 'Ban'), isNull);
    });

    test('the site language from the app language', () {
      expect(coopLanguage('de'), 'de');
      expect(coopLanguage('fr'), 'fr');
      expect(coopLanguage('es'), 'en');
    });

    test('a reply that ended at the sign-in is signed out', () {
      expect(
        const CoopReply(
          status: 200,
          url: 'https://login.supercard.ch/cas/login',
        ).signedOut,
        isTrue,
      );
      expect(const CoopReply(status: 0, error: 'TypeError').signedOut, isTrue);
      expect(
        const CoopReply(status: 200, url: '$coopOrigin/de/x').signedOut,
        isFalse,
      );
    });
  });

  group('a push', () {
    test('the first one creates the WuselWall list and fills it', () async {
      final coop = FakeCoop(generic: {'Milch': '1'});
      final (result, state) = await _push(coop, [
        _h('1', 'Milch'),
        _h('2', 'Brot', '2× Brot'),
      ]);
      expect(coop.lists, hasLength(1));
      expect(coop.shown, ['Milch', '2× Brot']);
      expect(state.listId, coop.active);
      expect(state.entries.keys, ['1', '2']);
      expect(result.sent, 2);
      expect(result.complete, isTrue);
      expect(state.lastPushCount, 2);
      expect(state.lastPushAt, DateTime.utc(2026, 10, 31, 12));
      // The picture of the generic catalogue when the name matches it exactly.
      final adds = coop.posted.where((f) => f.containsKey('productName'));
      expect(adds.first['productId'], '1');
      expect(adds.last.containsKey('productId'), isFalse);
      expect(coop.posted.first['listName'], coopListName);
    });

    test('a second one with nothing new sends nothing', () async {
      final coop = FakeCoop();
      final (_, first) = await _push(coop, [_h('1', 'Milch')]);
      coop.requests.clear();
      final (result, second) = await _push(coop, [_h('1', 'Milch')], first);
      expect(coop.requests, ['GET ${coopPanelPath('de')}']);
      expect(second.entries.keys, ['1']);
      expect(result.sent, 1);
    });

    test('a bought item leaves, a changed one is replaced', () async {
      final coop = FakeCoop();
      final (_, first) = await _push(coop, [_h('1', 'Milch'), _h('2', 'Brot')]);
      final (result, second) = await _push(coop, [
        _h('1', 'Milch', '2× Milch'),
      ], first);
      expect(coop.shown, ['2× Milch']);
      expect(second.entries.keys, ['1']);
      expect(second.entries['1']!.label, '2× Milch');
      expect(result.sent, 1);
    });

    test('what the family typed into the Coop list by hand stays', () async {
      final coop = FakeCoop();
      final (_, first) = await _push(coop, [_h('1', 'Milch')]);
      coop.lists[coop.active]!['BY-HAND'] = 'Kaffee';
      await _push(coop, const [], first);
      expect(coop.shown, ['Kaffee']);
    });

    test('a list deleted on the Coop side is made again', () async {
      final coop = FakeCoop();
      final (_, first) = await _push(coop, [_h('1', 'Milch')]);
      coop.lists.clear();
      coop.lists['OTHER'] = {'X': 'Familienliste'};
      final (_, second) = await _push(coop, [_h('1', 'Milch')], first);
      expect(second.listId, isNot(first.listId));
      expect(second.listId, isNot('OTHER'));
      expect(coop.lists['OTHER'], {'X': 'Familienliste'});
      expect(coop.lists[second.listId], {
        second.entries['1']!.entryId: 'Milch',
      });
    });

    test('without a session nothing is sent', () async {
      final coop = FakeCoop(signedIn: false);
      await expectLater(
        _push(coop, [_h('1', 'Milch')]),
        throwsA(isA<CoopSignedOut>()),
      );
      expect(coop.requests, isEmpty);
    });

    test('a session that ends half-way keeps what went across', () async {
      final coop = FakeCoop()..expireAfter = 4;
      final push = CoopPush(
        transport: coop,
        lang: 'de',
        state: const HandoffState(),
        spacing: Duration.zero,
      );
      await expectLater(
        push.run([_h('1', 'Milch'), _h('2', 'Brot'), _h('3', 'Eier')]),
        throwsA(isA<CoopSignedOut>()),
      );
      expect(push.state.listId, isNotNull);
      expect(push.state.entries.keys, ['1']);
    });

    test('an item the site refuses is counted, the rest go', () async {
      final coop = FakeCoop()..refuse.add('Brot');
      final (result, state) = await _push(coop, [
        _h('1', 'Milch'),
        _h('2', 'Brot'),
      ]);
      expect(result.sent, 1);
      expect(result.total, 2);
      expect(result.failed, 1);
      expect(result.complete, isFalse);
      expect(state.entries.keys, ['1']);
    });

    test('when every add fails the site has changed', () async {
      final coop = FakeCoop()..refuse.addAll(['Milch', 'Brot']);
      await expectLater(
        _push(coop, [_h('1', 'Milch'), _h('2', 'Brot')]),
        throwsA(isA<CoopUnexpected>()),
      );
    });

    test('every POST carries the page token', () async {
      final coop = FakeCoop();
      await _push(coop, [_h('1', 'Milch')]);
      expect(coop.posted, isNotEmpty);
      expect(
        coop.posted.every((f) => f[coopCsrfField] == FakeCoop.csrf),
        isTrue,
      );
    });
  });
}
