class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.checked,
    required this.createdAt,
    this.listId,
    this.categoryId,
    this.addedBy,
    this.count = 1,
    this.pending = false,
    this.sourceMealEntryIds = const [],
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as String?,
    checked: json['checked'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    listId: json['list_id'] as String?,
    categoryId: json['category_id'] as String?,
    addedBy: json['added_by'] as String?,
    count: json['count'] as int? ?? 1,
    sourceMealEntryIds: ((json['source_meal_entry_ids'] as List?) ?? const [])
        .cast<String>(),
  );

  final String id;
  final String name;

  /// The free-text specification ("Bio", "500 g"), verbatim.
  final String? quantity;
  final bool checked;
  final DateTime createdAt;
  final String? listId;
  final String? categoryId;
  final String? addedBy;

  /// How many times the tile was tapped ("2 ×").
  final int count;

  /// Changed on this device and not yet confirmed by the server ("wartet").
  final bool pending;

  /// The meal entries that put this item on the list (FR-3.7); empty for hand-added items.
  /// Kept in the offline snapshot too, so the list shows them without a connection.
  final List<String> sourceMealEntryIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'checked': checked,
    'created_at': createdAt.toIso8601String(),
    'list_id': listId,
    'category_id': categoryId,
    'added_by': addedBy,
    'count': count,
    'source_meal_entry_ids': sourceMealEntryIds,
  };

  ShoppingItem copyWith({
    bool? checked,
    String? quantity,
    bool clearQuantity = false,
    String? categoryId,
    bool clearCategory = false,
    int? count,
    bool? pending,
  }) => ShoppingItem(
    id: id,
    name: name,
    quantity: clearQuantity ? null : quantity ?? this.quantity,
    checked: checked ?? this.checked,
    createdAt: createdAt,
    listId: listId,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    addedBy: addedBy,
    count: count ?? this.count,
    pending: pending ?? this.pending,
    sourceMealEntryIds: sourceMealEntryIds,
  );
}

/// A meal behind a shopping item (`api.shopping_item_meals`), shown in the item's sheet.
class ShoppingItemMeal {
  const ShoppingItemMeal({
    required this.mealEntryId,
    required this.onDate,
    this.title,
  });

  factory ShoppingItemMeal.fromJson(Map<String, dynamic> json) =>
      ShoppingItemMeal(
        mealEntryId: json['meal_entry_id'] as String,
        onDate: DateTime.parse(json['on_date'] as String),
        title: json['title'] as String?,
      );

  final String mealEntryId;
  final DateTime onDate;

  /// The dish's name; null when the recipe behind it is gone.
  final String? title;
}

/// A named list (Supermarkt, Drogerie, …). One is the default.
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.openCount,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
    id: json['id'] as String,
    name: json['name'] as String,
    isDefault: json['is_default'] as bool,
    openCount: json['open_count'] as int,
  );

  final String id;
  final String name;
  final bool isDefault;
  final int openCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'is_default': isDefault,
    'open_count': openCount,
  };

  ShoppingList withOpenCount(int count) =>
      ShoppingList(id: id, name: name, isDefault: isDefault, openCount: count);
}

/// A category of a list: its order is the walking order of the store. Seeded ones carry
/// a [key] the app localises; custom ones carry a [name].
class ShoppingCategory {
  const ShoppingCategory({
    required this.id,
    required this.listId,
    required this.key,
    required this.name,
    required this.sortOrder,
  });

  factory ShoppingCategory.fromJson(Map<String, dynamic> json) =>
      ShoppingCategory(
        id: json['id'] as String,
        listId: json['list_id'] as String,
        key: json['key'] as String?,
        name: json['name'] as String?,
        sortOrder: json['sort_order'] as int,
      );

  final String id;
  final String listId;
  final String? key;
  final String? name;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'id': id,
    'list_id': listId,
    'key': key,
    'name': name,
    'sort_order': sortOrder,
  };
}

/// What the household has bought on a list before; a tile in the picker.
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.listId,
    required this.name,
    required this.foldedName,
    required this.categoryId,
    required this.purchaseCount,
    required this.lastPurchasedAt,
  });

  factory CatalogEntry.fromJson(Map<String, dynamic> json) => CatalogEntry(
    id: json['id'] as String,
    listId: json['list_id'] as String,
    name: json['name'] as String,
    foldedName: json['folded_name'] as String,
    categoryId: json['category_id'] as String?,
    purchaseCount: json['purchase_count'] as int,
    lastPurchasedAt: json['last_purchased_at'] == null
        ? null
        : DateTime.parse(json['last_purchased_at'] as String),
  );

  final String id;
  final String listId;
  final String name;
  final String foldedName;
  final String? categoryId;
  final int purchaseCount;
  final DateTime? lastPurchasedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'list_id': listId,
    'name': name,
    'folded_name': foldedName,
    'category_id': categoryId,
    'purchase_count': purchaseCount,
    'last_purchased_at': lastPurchasedAt?.toIso8601String(),
  };
}

/// One finished shopping trip.
class ShoppingTrip {
  const ShoppingTrip({
    required this.id,
    required this.listId,
    required this.finishedAt,
    required this.itemCount,
  });

  factory ShoppingTrip.fromJson(Map<String, dynamic> json) => ShoppingTrip(
    id: json['id'] as String,
    listId: json['list_id'] as String,
    finishedAt: DateTime.parse(json['finished_at'] as String),
    itemCount: json['item_count'] as int,
  );

  final String id;
  final String listId;
  final DateTime finishedAt;
  final int itemCount;
}

/// What `api.shopping_finish` reports.
class ShoppingFinishResult {
  const ShoppingFinishResult({required this.bought, required this.carriedOver});

  factory ShoppingFinishResult.fromJson(Map<String, dynamic> json) =>
      ShoppingFinishResult(
        bought: json['bought'] as int,
        carriedOver: json['carried_over'] as int,
      );

  final int bought;
  final int carriedOver;
}

/// An item as it was bought on a trip.
class TripItem {
  const TripItem({
    required this.name,
    required this.quantity,
    required this.count,
  });

  factory TripItem.fromJson(Map<String, dynamic> json) => TripItem(
    name: json['name'] as String,
    quantity: json['quantity'] as String?,
    count: json['count'] as int,
  );

  final String name;
  final String? quantity;
  final int count;
}
