import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

// The outbox's pure parts: the projection that mirrors api.shopping_apply, the wire
// format, and the two stores (specs/07#offline).

ShoppingItem it(
  String id,
  String name, {
  String list = 'l1',
  bool checked = false,
  int count = 1,
}) => ShoppingItem(
  id: id,
  name: name,
  quantity: null,
  checked: checked,
  createdAt: DateTime.utc(2026, 10, 12),
  listId: list,
  count: count,
);

ShoppingSnapshot snap(List<ShoppingItem> items) => ShoppingSnapshot(
  items: items,
  lists: const [
    ShoppingList(id: 'l1', name: 'Supermarkt', isDefault: true, openCount: 0),
    ShoppingList(id: 'l2', name: 'Drogerie', isDefault: false, openCount: 0),
  ],
  categories: const [],
  catalog: [
    CatalogEntry(
      id: 'c1',
      listId: 'l1',
      name: 'Äpfel',
      foldedName: 'aepfel',
      categoryId: 'cat-produce',
      purchaseCount: 3,
      lastPurchasedAt: DateTime.utc(2026, 10),
      iconKey: 'apple',
    ),
  ],
);

int _n = 0;
String op() => 'op-${_n++}';

void main() {
  group('projectShopping', () {
    test('an add shows at once, pending, with the catalogue spelling', () {
      final view = projectShopping(snap([]), [
        AddItemOp(
          opId: op(),
          actor: 'kid',
          itemId: 'n1',
          listId: 'l1',
          name: ' aepfel ',
        ),
      ]);
      final added = view.items.single;
      expect(added.id, 'n1');
      expect(added.name, 'Äpfel');
      expect(added.categoryId, 'cat-produce');
      expect(added.addedBy, 'kid');
      expect(added.pending, isTrue);
      expect(view.pendingCount, 1);
      expect(view.lists.first.openCount, 1);
    });

    test('adding an open name merges, and the merged id still reaches it', () {
      final view = projectShopping(snap([it('m', 'Milch')]), [
        AddItemOp(
          opId: op(),
          actor: null,
          itemId: 'n2',
          listId: 'l1',
          name: 'MILCH',
        ),
        SpecItemOp(opId: op(), actor: null, itemId: 'n2', text: 'Bio'),
      ]);
      expect(view.items, hasLength(1));
      expect(view.items.single.count, 2);
      expect(view.items.single.quantity, 'Bio');
      expect(view.items.single.pending, isTrue);
    });

    test('a ticked item does not absorb a new add of the same name', () {
      final view = projectShopping(snap([it('m', 'Milch', checked: true)]), [
        AddItemOp(
          opId: op(),
          actor: null,
          itemId: 'n3',
          listId: 'l1',
          name: 'Milch',
        ),
      ]);
      expect(view.items, hasLength(2));
    });

    test('an item on another list is not merged', () {
      final view = projectShopping(snap([it('m', 'Milch', list: 'l2')]), [
        AddItemOp(
          opId: op(),
          actor: null,
          itemId: 'n4',
          listId: 'l1',
          name: 'Milch',
        ),
      ]);
      expect(view.items, hasLength(2));
    });

    test('check, count, spec and category change only their item', () {
      final view = projectShopping(snap([it('a', 'Brot'), it('b', 'Käse')]), [
        CheckItemOp(opId: op(), actor: null, itemId: 'a', checked: true),
        CountItemOp(opId: op(), actor: null, itemId: 'a', delta: 2),
        CategoriseItemOp(opId: op(), actor: null, itemId: 'a', categoryId: 'x'),
      ]);
      final a = view.items.firstWhere((i) => i.id == 'a');
      final b = view.items.firstWhere((i) => i.id == 'b');
      expect(
        (a.checked, a.count, a.categoryId, a.pending),
        (true, 3, 'x', true),
      );
      expect(b.pending, isFalse);
      expect(view.lists.first.openCount, 1);
    });

    test(
      'a count reaching zero removes the item; later ops on it are skipped',
      () {
        final view = projectShopping(snap([it('a', 'Brot')]), [
          CountItemOp(opId: op(), actor: null, itemId: 'a', delta: -1),
          CheckItemOp(opId: op(), actor: null, itemId: 'a', checked: true),
        ]);
        expect(view.items, isEmpty);
      },
    );

    test('an op on an item that is gone changes nothing', () {
      final view = projectShopping(snap([it('a', 'Brot')]), [
        CheckItemOp(opId: op(), actor: null, itemId: 'gone', checked: true),
      ]);
      expect(view.items.single.pending, isFalse);
    });

    test('finish takes the ticked items of that list only', () {
      final view = projectShopping(
        snap([
          it('a', 'Brot', checked: true),
          it('b', 'Käse'),
          it('c', 'Seife', list: 'l2', checked: true),
        ]),
        [FinishTripOp(opId: op(), actor: null, tripId: 't', listId: 'l1')],
      );
      expect(view.items.map((i) => i.id), ['b', 'c']);
    });

    test('a count never leaves 1..99', () {
      final view = projectShopping(snap([it('a', 'Brot', count: 98)]), [
        CountItemOp(opId: op(), actor: null, itemId: 'a', delta: 5),
      ]);
      expect(view.items.single.count, 99);
    });
  });

  group('wire format', () {
    test('every op survives a round trip through JSON', () {
      final ops = <ShoppingOp>[
        AddItemOp(
          opId: 'o1',
          actor: 'p',
          itemId: 'i',
          listId: 'l',
          name: 'Milch',
          quantity: '2 l',
        ),
        const CheckItemOp(opId: 'o2', actor: null, itemId: 'i', checked: true),
        const CountItemOp(opId: 'o3', actor: 'p', itemId: 'i', delta: -1),
        const SpecItemOp(opId: 'o4', actor: 'p', itemId: 'i', text: null),
        const CategoriseItemOp(
          opId: 'o5',
          actor: 'p',
          itemId: 'i',
          categoryId: 'c',
        ),
        const FinishTripOp(opId: 'o6', actor: 'p', tripId: 't', listId: 'l'),
      ];
      for (final o in ops) {
        final json = jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>;
        expect(ShoppingOp.fromJson(json).toJson(), o.toJson());
      }
      expect(
        ops[1].toJson().containsKey('actor'),
        isFalse,
        reason: 'a personal device sends no actor',
      );
      expect(ops[0].toJson()['kind'], 'add');
    });

    test('a snapshot survives a round trip through JSON', () {
      final s = snap([it('a', 'Brot', count: 2)]);
      final back = ShoppingSnapshot.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), s.toJson());
    });
  });

  for (final (name, make) in <(String, ShoppingStore Function())>[
    ('memory', MemoryShoppingStore.new),
    ('drift (SQLite)', () => DriftShoppingStore(NativeDatabase.memory())),
  ]) {
    group('$name store', () {
      late ShoppingStore store;
      setUp(() => store = make());
      tearDown(() async {
        if (store case final DriftShoppingStore d) await d.close();
      });

      test('keeps the snapshot and the outbox in order', () async {
        expect(await store.readSnapshot('h1'), isNull);
        await store.writeSnapshot('h1', snap([it('a', 'Brot')]));
        for (final id in ['o1', 'o2', 'o3']) {
          await store.append(
            'h1',
            CheckItemOp(opId: id, actor: null, itemId: 'a', checked: true),
          );
        }
        expect((await store.readSnapshot('h1'))!.items.single.name, 'Brot');
        expect((await store.readOutbox('h1')).map((o) => o.opId), [
          'o1',
          'o2',
          'o3',
        ]);

        await store.remove(['o1', 'o3']);
        expect((await store.readOutbox('h1')).map((o) => o.opId), ['o2']);
      });

      test('another household starts empty', () async {
        await store.writeSnapshot('h1', snap([it('a', 'Brot')]));
        await store.append(
          'h1',
          const CheckItemOp(
            opId: 'o1',
            actor: null,
            itemId: 'a',
            checked: true,
          ),
        );
        expect(await store.readSnapshot('h2'), isNull);
        expect(await store.readOutbox('h2'), isEmpty);
      });
    });
  }

  test(
    'the drift store keeps an op once, however often it is appended',
    () async {
      final store = DriftShoppingStore(NativeDatabase.memory());
      addTearDown(store.close);
      const o = CheckItemOp(
        opId: 'o1',
        actor: null,
        itemId: 'a',
        checked: true,
      );
      await store.append('h1', o);
      await store.append('h1', o);
      expect(await store.readOutbox('h1'), hasLength(1));
    },
  );
}
