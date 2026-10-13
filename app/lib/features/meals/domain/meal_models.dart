import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart' show parseDate;

/// The four slots of a day (`meal_plan_entry.slot`). Named apart from the board's
/// `MealSlot`, which only knows the two warm meals the wall shows.
enum PlanSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  static PlanSlot parse(String v) => switch (v) {
    'breakfast' => breakfast,
    'lunch' => lunch,
    'dinner' => dinner,
    'snack' => snack,
    _ => throw FormatException('Unknown meal slot $v'),
  };

  /// The wire value, which is also the enum name.
  String get wire => name;
}

/// A recipe's ingredient row (`app.recipe_ingredient`). [quantity] and [unit] are
/// optional: "Salz" needs neither, "2 Zwiebeln" has no unit.
class RecipeIngredient {
  const RecipeIngredient({
    required this.rawName,
    this.id,
    this.catalogItemId,
    this.quantity,
    this.unit,
    this.note,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as String?,
        rawName: json['raw_name'] as String,
        catalogItemId: json['catalog_item_id'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        note: json['note'] as String?,
      );

  final String? id;
  final String rawName;
  final String? catalogItemId;
  final double? quantity;
  final String? unit;
  final String? note;

  /// The row as `api.recipe_save` takes it: position comes from the array's order.
  Map<String, dynamic> toJson() => {
    'raw_name': rawName,
    'catalog_item_id': catalogItemId,
    'quantity': quantity,
    'unit': unit,
    'note': note,
  };

  RecipeIngredient copyWith({
    String? rawName,
    double? quantity,
    String? unit,
    String? note,
    bool clearQuantity = false,
    bool clearUnit = false,
    bool clearNote = false,
  }) => RecipeIngredient(
    id: id,
    rawName: rawName ?? this.rawName,
    catalogItemId: catalogItemId,
    quantity: clearQuantity ? null : (quantity ?? this.quantity),
    unit: clearUnit ? null : (unit ?? this.unit),
    note: clearNote ? null : (note ?? this.note),
  );
}

/// A recipe with its ingredients in order. Recipes are optional enrichment: a meal
/// without one is complete with free text (specs/07, "Deliberate minimalism").
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.servingsDefault,
    this.description,
    this.steps,
    this.sourceUrl,
    this.tags = const [],
    this.ingredients = const [],
  });

  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    List<RecipeIngredient> ingredients = const [],
  }) => Recipe(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    servingsDefault: json['servings_default'] as int? ?? 4,
    steps: json['steps'] as String?,
    sourceUrl: json['source_url'] as String?,
    tags: ((json['tags'] as List?) ?? const []).cast<String>(),
    ingredients: ingredients,
  );

  final String id;
  final String title;
  final String? description;
  final int servingsDefault;

  /// Free text, one step per line.
  final String? steps;
  final String? sourceUrl;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;

  /// The steps as lines, without blank ones.
  List<String> get stepLines => [
    for (final line in (steps ?? '').split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  Recipe copyWith({
    String? title,
    int? servingsDefault,
    String? steps,
    String? sourceUrl,
    List<String>? tags,
    List<RecipeIngredient>? ingredients,
    bool clearSourceUrl = false,
    bool clearSteps = false,
  }) => Recipe(
    id: id,
    title: title ?? this.title,
    description: description,
    servingsDefault: servingsDefault ?? this.servingsDefault,
    steps: clearSteps ? null : (steps ?? this.steps),
    sourceUrl: clearSourceUrl ? null : (sourceUrl ?? this.sourceUrl),
    tags: tags ?? this.tags,
    ingredients: ingredients ?? this.ingredients,
  );
}

/// Scales one ingredient quantity from a recipe's default servings to [servings].
/// Display rounding is the caller's job.
double? scaleQuantity(double? quantity, int from, int servings) =>
    quantity == null || from <= 0 ? quantity : quantity * servings / from;

/// One day's slot (`api.meal_plan_entries`). Both [recipeId] and [freeText] are null for
/// a slot that only carries eating overrides.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.onDate,
    required this.slot,
    this.recipeId,
    this.freeText,
    this.title,
    this.servings,
    this.cookProfileId,
    this.atTime,
    this.guests = 0,
    this.eatingOverrides = const {},
    this.shoppingGeneratedAt,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: json['id'] as String,
    onDate: parseDate(json['on_date'] as String),
    slot: PlanSlot.parse(json['slot'] as String),
    recipeId: json['recipe_id'] as String?,
    freeText: json['free_text'] as String?,
    title: json['title'] as String?,
    servings: json['servings'] as int?,
    cookProfileId: json['cook_profile_id'] as String?,
    atTime: _time(json['at_time']),
    guests: json['guests'] as int? ?? 0,
    eatingOverrides: {
      for (final e in ((json['eating_overrides'] as Map?) ?? const {}).entries)
        e.key as String: e.value as bool,
    },
    shoppingGeneratedAt: json['shopping_generated_at'] == null
        ? null
        : DateTime.parse(json['shopping_generated_at'] as String),
  );

  final String id;
  final DateTime onDate;
  final PlanSlot slot;
  final String? recipeId;
  final String? freeText;

  /// The dish's name: the recipe's title, else the free text (server-computed).
  final String? title;
  final int? servings;
  final String? cookProfileId;
  final TimeOfDay? atTime;
  final int guests;

  /// `{"<profile_id>": true|false}`; members absent follow the default rule.
  final Map<String, bool> eatingOverrides;
  final DateTime? shoppingGeneratedAt;

  /// Whether a dish is planned (a recipe or free text), not just overrides.
  bool get hasDish => (title ?? '').trim().isNotEmpty;
}

/// One line of the mandatory shopping preview (`api.meal_shopping_preview`).
class MealShoppingItem {
  const MealShoppingItem({
    required this.key,
    required this.name,
    required this.mealEntryIds,
    required this.alreadyOnList,
    this.quantity,
    this.unit,
    this.catalogItemId,
  });

  factory MealShoppingItem.fromJson(Map<String, dynamic> json) =>
      MealShoppingItem(
        key: json['key'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        catalogItemId: json['catalog_item_id'] as String?,
        mealEntryIds: ((json['meal_entry_ids'] as List?) ?? const [])
            .cast<String>(),
        alreadyOnList: json['already_on_list'] as bool? ?? false,
      );

  /// Stable across previews of the same week; sent back as the checked keys.
  final String key;
  final String name;
  final double? quantity;
  final String? unit;
  final String? catalogItemId;

  /// The meals the item comes from.
  final List<String> mealEntryIds;

  /// An open item with the same name is already on the default list.
  final bool alreadyOnList;
}

TimeOfDay? _time(Object? v) {
  if (v == null) return null;
  final p = (v as String).split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}
