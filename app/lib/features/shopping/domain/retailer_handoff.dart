import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Handing the open items of a list to a supermarket's own list (specs/30): the parts
/// that know nothing about the supermarket. WuselWall stays the source of truth; the
/// other list is made equal to it on each push, one way.

/// The longest label sent; a longer name is cut with an ellipsis.
const handoffLabelMax = 80;

/// One open item as it goes to the other list.
class HandoffItem {
  const HandoffItem({
    required this.id,
    required this.name,
    required this.label,
  });

  /// WuselWall's item id, the key of the remembered entry.
  final String id;

  /// The bare name, for picking a picture on the other side ("Milch").
  final String name;

  /// What the other list shows: the count when above one and the note ("2× Milch (Bio)").
  final String label;
}

/// The label of [item] on the other list. Built from the item alone, so the same item
/// gives the same label on every device and every push.
String handoffLabel(ShoppingItem item) {
  final name = item.name.trim();
  final count = item.count > 1 ? '${item.count}× ' : '';
  final note = item.quantity?.trim() ?? '';
  final label = note.isEmpty ? '$count$name' : '$count$name ($note)';
  if (label.length <= handoffLabelMax) return label;
  return '${label.substring(0, handoffLabelMax - 1).trimRight()}…';
}

/// The open items of [items] that go across, in the order of the list.
List<HandoffItem> handoffItems(Iterable<ShoppingItem> items) => [
  for (final item in items)
    if (!item.checked && item.name.trim().isNotEmpty)
      HandoffItem(
        id: item.id,
        name: item.name.trim(),
        label: handoffLabel(item),
      ),
];

/// An entry this device created on the other list, for one WuselWall item.
class HandoffEntry {
  const HandoffEntry({required this.entryId, required this.label});

  factory HandoffEntry.fromJson(Map<String, dynamic> json) => HandoffEntry(
    entryId: json['entry'] as String,
    label: json['label'] as String,
  );

  final String entryId;

  /// The label it was created with: a renamed item, a new count or note replaces it.
  final String label;

  Map<String, dynamic> toJson() => {'entry': entryId, 'label': label};
}

/// What one push does: [remove] the entries whose item is gone, ticked or changed, [add]
/// the items without an entry, [keep] the rest as they are.
class HandoffPlan {
  const HandoffPlan({
    required this.remove,
    required this.add,
    required this.keep,
  });

  /// Entry ids on the other list, and the item each belonged to.
  final Map<String, String> remove;
  final List<HandoffItem> add;
  final Map<String, HandoffEntry> keep;

  bool get isEmpty => remove.isEmpty && add.isEmpty;
}

/// The plan that makes the entries this device created equal to [open]. Entries it did
/// not create are not in [remembered] and so are never touched: what the family typed
/// on the other side by hand stays.
HandoffPlan planHandoff(
  List<HandoffItem> open,
  Map<String, HandoffEntry> remembered,
) {
  final byId = {for (final item in open) item.id: item};
  final remove = <String, String>{};
  final keep = <String, HandoffEntry>{};
  for (final MapEntry(key: itemId, value: entry) in remembered.entries) {
    final item = byId[itemId];
    if (item != null && item.label == entry.label) {
      keep[itemId] = entry;
    } else {
      remove[entry.entryId] = itemId;
    }
  }
  return HandoffPlan(
    remove: remove,
    add: [
      for (final item in open)
        if (!keep.containsKey(item.id)) item,
    ],
    keep: keep,
  );
}

/// This device's link to the other list: kept on the device only, never on the server.
class HandoffState {
  const HandoffState({
    this.listId,
    this.entries = const {},
    this.lastPushAt,
    this.lastPushCount,
  });

  factory HandoffState.fromJson(Map<String, dynamic> json) => HandoffState(
    listId: json['list'] as String?,
    entries: {
      for (final MapEntry(:key, :value)
          in ((json['entries'] as Map?) ?? const {}).entries)
        key as String: HandoffEntry.fromJson(
          (value as Map).cast<String, dynamic>(),
        ),
    },
    lastPushAt: switch (json['pushed_at']) {
      final String at => DateTime.tryParse(at),
      _ => null,
    },
    lastPushCount: json['pushed'] as int?,
  );

  /// The list on the other side the pushes go to; null until the first push made it.
  final String? listId;

  /// WuselWall item id → the entry made for it.
  final Map<String, HandoffEntry> entries;
  final DateTime? lastPushAt;

  /// How many items the other list held for this device after the last push.
  final int? lastPushCount;

  HandoffState copyWith({
    String? listId,
    bool clearList = false,
    Map<String, HandoffEntry>? entries,
    DateTime? lastPushAt,
    int? lastPushCount,
  }) => HandoffState(
    listId: clearList ? null : listId ?? this.listId,
    entries: entries ?? this.entries,
    lastPushAt: lastPushAt ?? this.lastPushAt,
    lastPushCount: lastPushCount ?? this.lastPushCount,
  );

  Map<String, dynamic> toJson() => {
    'list': listId,
    'entries': {
      for (final MapEntry(:key, :value) in entries.entries) key: value.toJson(),
    },
    'pushed_at': lastPushAt?.toUtc().toIso8601String(),
    'pushed': lastPushCount,
  };
}

/// How a push ended.
class HandoffResult {
  const HandoffResult({
    required this.sent,
    required this.total,
    required this.failed,
  });

  /// Items on the other list for this device now.
  final int sent;

  /// Open items in WuselWall.
  final int total;

  /// Items that could not be added this time.
  final int failed;

  bool get complete => failed == 0;
}
