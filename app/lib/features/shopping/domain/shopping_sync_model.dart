import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// One change waiting in the outbox (specs/07#offline). Each carries a client-generated
/// [opId], the idempotency key `api.shopping_apply` records, and the acting profile at
/// the moment it was made — a shared tablet queues several people's changes.
sealed class ShoppingOp {
  const ShoppingOp({required this.opId, required this.actor});

  factory ShoppingOp.fromJson(Map<String, dynamic> json) {
    final opId = json['op_id'] as String;
    final actor = json['actor'] as String?;
    return switch (json['kind']) {
      'add' => AddItemOp(
        opId: opId,
        actor: actor,
        itemId: json['item_id'] as String,
        listId: json['list_id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as String?,
      ),
      'check' => CheckItemOp(
        opId: opId,
        actor: actor,
        itemId: json['item_id'] as String,
        checked: json['checked'] as bool,
      ),
      'count' => CountItemOp(
        opId: opId,
        actor: actor,
        itemId: json['item_id'] as String,
        delta: json['delta'] as int,
      ),
      'spec' => SpecItemOp(
        opId: opId,
        actor: actor,
        itemId: json['item_id'] as String,
        text: json['text'] as String?,
      ),
      'category' => CategoriseItemOp(
        opId: opId,
        actor: actor,
        itemId: json['item_id'] as String,
        categoryId: json['category_id'] as String?,
      ),
      'finish' => FinishTripOp(
        opId: opId,
        actor: actor,
        tripId: json['trip_id'] as String,
        listId: json['list_id'] as String,
      ),
      final kind => throw FormatException('unknown shopping op $kind'),
    };
  }

  final String opId;

  /// The acting profile; null on a personal device, whose profile is fixed.
  final String? actor;

  String get kind;

  /// The item this op changes, if any.
  String? get itemId => null;

  Map<String, dynamic> get _fields;

  /// The wire format of `api.shopping_apply`, also how the outbox stores it.
  Map<String, dynamic> toJson() => {
    'op_id': opId,
    'kind': kind,
    'actor': ?actor,
    ..._fields,
  };
}

final class AddItemOp extends ShoppingOp {
  const AddItemOp({
    required super.opId,
    required super.actor,
    required this.itemId,
    required this.listId,
    required this.name,
    this.quantity,
  });

  @override
  final String itemId;
  final String listId;
  final String name;
  final String? quantity;

  @override
  String get kind => 'add';

  @override
  Map<String, dynamic> get _fields => {
    'item_id': itemId,
    'list_id': listId,
    'name': name,
    'quantity': ?quantity,
  };
}

/// Absolute, not a toggle, so applying it twice changes nothing.
final class CheckItemOp extends ShoppingOp {
  const CheckItemOp({
    required super.opId,
    required super.actor,
    required this.itemId,
    required this.checked,
  });

  @override
  final String itemId;
  final bool checked;

  @override
  String get kind => 'check';

  @override
  Map<String, dynamic> get _fields => {'item_id': itemId, 'checked': checked};
}

/// +1 / -1 from the tile; reaching zero removes the item.
final class CountItemOp extends ShoppingOp {
  const CountItemOp({
    required super.opId,
    required super.actor,
    required this.itemId,
    required this.delta,
  });

  @override
  final String itemId;
  final int delta;

  @override
  String get kind => 'count';

  @override
  Map<String, dynamic> get _fields => {'item_id': itemId, 'delta': delta};
}

final class SpecItemOp extends ShoppingOp {
  const SpecItemOp({
    required super.opId,
    required super.actor,
    required this.itemId,
    required this.text,
  });

  @override
  final String itemId;
  final String? text;

  @override
  String get kind => 'spec';

  @override
  Map<String, dynamic> get _fields => {'item_id': itemId, 'text': text};
}

final class CategoriseItemOp extends ShoppingOp {
  const CategoriseItemOp({
    required super.opId,
    required super.actor,
    required this.itemId,
    required this.categoryId,
  });

  @override
  final String itemId;
  final String? categoryId;

  @override
  String get kind => 'category';

  @override
  Map<String, dynamic> get _fields => {
    'item_id': itemId,
    'category_id': categoryId,
  };
}

final class FinishTripOp extends ShoppingOp {
  const FinishTripOp({
    required super.opId,
    required super.actor,
    required this.tripId,
    required this.listId,
  });

  final String tripId;
  final String listId;

  @override
  String get kind => 'finish';

  @override
  Map<String, dynamic> get _fields => {'trip_id': tripId, 'list_id': listId};
}

/// The server's state as last fetched: the mirror the outbox is replayed on.
class ShoppingSnapshot {
  const ShoppingSnapshot({
    required this.items,
    required this.lists,
    required this.categories,
    required this.catalog,
  });

  factory ShoppingSnapshot.fromJson(Map<String, dynamic> json) =>
      ShoppingSnapshot(
        items: _parse(json['items'], ShoppingItem.fromJson),
        lists: _parse(json['lists'], ShoppingList.fromJson),
        categories: _parse(json['categories'], ShoppingCategory.fromJson),
        catalog: _parse(json['catalog'], CatalogEntry.fromJson),
      );

  final List<ShoppingItem> items;
  final List<ShoppingList> lists;
  final List<ShoppingCategory> categories;
  final List<CatalogEntry> catalog;

  ShoppingSnapshot withItems(List<ShoppingItem> items) => ShoppingSnapshot(
    items: items,
    lists: lists,
    categories: categories,
    catalog: catalog,
  );

  Map<String, dynamic> toJson() => {
    'items': [for (final i in items) i.toJson()],
    'lists': [for (final l in lists) l.toJson()],
    'categories': [for (final c in categories) c.toJson()],
    'catalog': [for (final c in catalog) c.toJson()],
  };
}

List<T> _parse<T>(Object? rows, T Function(Map<String, dynamic>) parse) => [
  for (final row in (rows as List<dynamic>? ?? const []))
    parse(row as Map<String, dynamic>),
];

/// What `api.shopping_apply` reports: a status per op, and the household's open items
/// afterwards, which replace the mirror's.
class ApplyResult {
  const ApplyResult({required this.results, required this.items});

  factory ApplyResult.fromJson(Map<String, dynamic> json) => ApplyResult(
    results: [
      for (final r in json['results'] as List<dynamic>)
        OpResult.fromJson(r as Map<String, dynamic>),
    ],
    items: _parse(json['items'], ShoppingItem.fromJson),
  );

  final List<OpResult> results;
  final List<ShoppingItem> items;
}

/// `applied`, `duplicate` (seen before), `skipped` (nothing left to act on) or
/// `rejected`, with the domain [code] that explains why.
class OpResult {
  const OpResult({required this.opId, required this.status, this.code});

  factory OpResult.fromJson(Map<String, dynamic> json) => OpResult(
    opId: json['op_id'] as String,
    status: json['status'] as String,
    code: json['code'] as String?,
  );

  final String opId;
  final String status;
  final String? code;

  bool get rejected => status == 'rejected';
}

/// What the screen shows: the snapshot with the outbox replayed on top.
class ShoppingView {
  const ShoppingView({
    required this.items,
    required this.lists,
    required this.categories,
    required this.catalog,
    required this.pendingCount,
  });

  final List<ShoppingItem> items;
  final List<ShoppingList> lists;
  final List<ShoppingCategory> categories;
  final List<CatalogEntry> catalog;

  /// Changes made on this device that the server has not confirmed yet.
  final int pendingCount;
}

/// Replays [ops] on [snapshot] with the same rules as `api.shopping_apply`, so the
/// screen shows offline changes the way the server will apply them. Items touched by an
/// op are marked pending. Pure: the outbox, the demo build and the tests share it.
ShoppingView projectShopping(ShoppingSnapshot snapshot, List<ShoppingOp> ops) {
  final items = [for (final i in snapshot.items) i];
  // A client id an add was merged under (two people added the same item).
  final alias = <String, String>{};

  int find(String id) {
    final target = alias[id] ?? id;
    return items.indexWhere((i) => i.id == target);
  }

  void change(String id, ShoppingItem? Function(ShoppingItem) update) {
    final at = find(id);
    if (at < 0) return; // gone: the tombstone wins, as on the server
    final next = update(items[at]);
    if (next == null) {
      items.removeAt(at);
    } else {
      items[at] = next.copyWith(pending: true);
    }
  }

  for (final op in ops) {
    switch (op) {
      case AddItemOp():
        if (find(op.itemId) >= 0) break;
        final folded = fold(op.name.trim());
        final open = items.indexWhere(
          (i) => i.listId == op.listId && !i.checked && fold(i.name) == folded,
        );
        if (open >= 0) {
          alias[op.itemId] = items[open].id;
          items[open] = items[open].copyWith(
            count: (items[open].count + 1).clamp(1, 99),
            pending: true,
          );
          break;
        }
        final known = snapshot.catalog
            .where((c) => c.listId == op.listId && c.foldedName == folded)
            .firstOrNull;
        final quantity = op.quantity?.trim();
        items.add(
          ShoppingItem(
            id: op.itemId,
            name: known?.name ?? op.name.trim(),
            quantity: quantity == null || quantity.isEmpty ? null : quantity,
            checked: false,
            createdAt: DateTime.now(),
            listId: op.listId,
            categoryId: known?.categoryId,
            addedBy: op.actor,
            pending: true,
          ),
        );
      case CheckItemOp(:final itemId, :final checked):
        change(itemId, (i) => i.copyWith(checked: checked));
      case CountItemOp(:final itemId, :final delta):
        change(itemId, (i) {
          final count = i.count + delta;
          return count <= 0 ? null : i.copyWith(count: count.clamp(1, 99));
        });
      case SpecItemOp(:final itemId, :final text):
        final spec = text?.trim() ?? '';
        change(
          itemId,
          (i) => spec.isEmpty
              ? i.copyWith(clearQuantity: true)
              : i.copyWith(quantity: spec),
        );
      case CategoriseItemOp(:final itemId, :final categoryId):
        change(
          itemId,
          (i) => categoryId == null
              ? i.copyWith(clearCategory: true)
              : i.copyWith(categoryId: categoryId),
        );
      case FinishTripOp(:final listId):
        items.removeWhere((i) => i.listId == listId && i.checked);
    }
  }

  return ShoppingView(
    items: items,
    lists: [
      for (final l in snapshot.lists)
        l.withOpenCount(
          items.where((i) => i.listId == l.id && !i.checked).length,
        ),
    ],
    categories: snapshot.categories,
    catalog: snapshot.catalog,
    pendingCount: ops.length,
  );
}
