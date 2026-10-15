import 'package:flutter/painting.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Invented family for the user documentation's screenshots (`lib/main_demo.dart`).
/// Nothing here is real data.
abstract final class DemoData {
  static const papa = 'p-papa';
  static const mama = 'p-mama';
  static const daughter = 'p-daughter';
  static const son = 'p-son';

  /// The family's names in German and in English: the demo speaks the app's language.
  static const _names = {
    papa: ('Thomas', 'David'),
    mama: ('Julia', 'Sarah'),
    daughter: ('Emma', 'Olivia'),
    son: ('Paul', 'Jack'),
  };

  static var _english = false;

  /// Whether the demo runs in English; set by [useLanguageOf] when the demo starts.
  static bool get english => _english;

  /// Picks the language as MaterialApp does from the device's [preferred] locales and
  /// app.dart's `supportedLocales`: the first German or English one, German otherwise.
  static void useLanguageOf(List<Locale> preferred) {
    final code = preferred
        .map((l) => l.languageCode)
        .firstWhere((c) => c == 'de' || c == 'en', orElse: () => 'de');
    _english = code == 'en';
  }

  /// The display name of the member [id].
  static String name(String id) {
    final (de, en) = _names[id]!;
    return _english ? en : de;
  }

  /// [de] in German, [en] in English: all of the demo's content speaks the app's
  /// language, not only the names.
  static String tr(String de, String en) => _english ? en : de;

  /// The father's phone, as the device list shows it.
  static String get papaPhone =>
      _english ? "${name(papa)}'s iPhone" : '${name(papa)}’ iPhone';

  static List<Member> get members => [
    Member(
      id: papa,
      displayName: name(papa),
      color: Color(0xFFC2255C),
      role: Role.guardian,
      active: true,
    ),
    Member(
      id: mama,
      displayName: name(mama),
      color: Color(0xFF9A5300),
      role: Role.guardian,
      active: true,
    ),
    Member(
      id: daughter,
      displayName: name(daughter),
      color: Color(0xFF7B3FE4),
      role: Role.member,
      active: true,
      isChild: true,
    ),
    Member(
      id: son,
      displayName: name(son),
      color: Color(0xFF08737F),
      role: Role.member,
      active: true,
      isChild: true,
    ),
  ];

  static List<(String, String, bool)> get lists => [
    ('l-super', tr('Supermarkt', 'Supermarket'), true),
    ('l-drug', tr('Drogerie', 'Pharmacy'), false),
    ('l-hardware', tr('Baumarkt', 'Hardware store'), false),
  ];

  static const superKeys = [
    'produce',
    'bakery',
    'dairy',
    'meat_fish',
    'pantry',
    'frozen',
    'drinks',
    'household',
    'other',
  ];

  static List<ShoppingCategory> categories() => [
    for (final (i, k) in superKeys.indexed)
      ShoppingCategory(
        id: 'c-$k',
        listId: 'l-super',
        key: k,
        name: null,
        sortOrder: i * 10,
      ),
    for (final (i, k) in [
      'care',
      'baby',
      'cleaning',
      'health',
      'other',
    ].indexed)
      ShoppingCategory(
        id: 'cd-$k',
        listId: 'l-drug',
        key: k,
        name: null,
        sortOrder: i * 10,
      ),
    for (final (i, k) in [
      'tools',
      'screws',
      'electrical',
      'garden',
      'other',
    ].indexed)
      ShoppingCategory(
        id: 'ch-$k',
        listId: 'l-hardware',
        key: k,
        name: null,
        sortOrder: i * 10,
      ),
  ];

  static final _now = DateTime(2026, 10, 11, 9);

  /// (name, category key, purchases) — what the household has bought before.
  static List<(String, String, int)> get _catalogue => [
    (tr('Milch', 'Milk'), 'dairy', 42),
    (tr('Brot', 'Bread'), 'bakery', 35),
    (tr('Bananen', 'Bananas'), 'produce', 31),
    (tr('Äpfel', 'Apples'), 'produce', 24),
    ('Butter', 'dairy', 22),
    (tr('Eier', 'Eggs'), 'dairy', 21),
    (tr('Nudeln', 'Pasta'), 'pantry', 19),
    (tr('Joghurt', 'Yoghurt'), 'dairy', 18),
    (tr('Tomaten', 'Tomatoes'), 'produce', 17),
    (tr('Käse', 'Cheese'), 'dairy', 16),
    (tr('Gurke', 'Cucumber'), 'produce', 12),
    (tr('Reis', 'Rice'), 'pantry', 11),
    (tr('Orangensaft', 'Orange juice'), 'drinks', 9),
    (tr('Toilettenpapier', 'Toilet paper'), 'household', 8),
    (tr('Gummibärchen', 'Gummy bears'), 'pantry', 7),
    (tr('Kartoffeln', 'Potatoes'), 'produce', 7),
  ];

  static List<CatalogEntry> catalogue() => [
    for (final (i, (name, cat, n)) in _catalogue.indexed)
      CatalogEntry(
        id: 'k-$i',
        listId: 'l-super',
        name: name,
        foldedName: name
            .toLowerCase()
            .replaceAll('ä', 'ae')
            .replaceAll('ö', 'oe')
            .replaceAll('ü', 'ue'),
        categoryId: 'c-$cat',
        purchaseCount: n,
        lastPurchasedAt: _now.subtract(Duration(days: i + 1)),
      ),
  ];

  /// The pasta, which came from two of the week's meals.
  static String get pasta => tr('Nudeln', 'Pasta');

  /// (name, category key, count, spec, added by, ticked)
  static List<(String, String, int, String?, String, bool)> get _items => [
    (tr('Bananen', 'Bananas'), 'produce', 1, null, daughter, false),
    (tr('Gurke', 'Cucumber'), 'produce', 2, null, mama, false),
    (
      tr('Brot', 'Bread'),
      'bakery',
      1,
      tr('Vollkorn', 'Wholemeal'),
      papa,
      false,
    ),
    (tr('Milch', 'Milk'), 'dairy', 2, tr('1,5 %', 'semi-skimmed'), papa, false),
    (
      tr('Joghurt', 'Yoghurt'),
      'dairy',
      1,
      tr('Natur, 500 g', 'plain, 500 g'),
      mama,
      false,
    ),
    (pasta, 'pantry', 1, null, son, false),
    (tr('Gummibärchen', 'Gummy bears'), 'pantry', 1, null, son, false),
    (tr('Orangensaft', 'Orange juice'), 'drinks', 1, null, mama, true),
    ('Butter', 'dairy', 1, null, papa, true),
  ];

  static List<ShoppingItem> items() => [
    for (final (i, (name, cat, count, spec, by, ticked)) in _items.indexed)
      ShoppingItem(
        id: 'i-$i',
        name: name,
        quantity: spec,
        checked: ticked,
        createdAt: _now.add(Duration(minutes: i)),
        listId: 'l-super',
        categoryId: 'c-$cat',
        addedBy: by,
        count: count,
        // The pasta came from two of the week's meals (see DemoShoppingRepository.itemMeals).
        sourceMealEntryIds: name == pasta
            ? const ['demo-src-nudel', 'demo-src-pesto']
            : const [],
      ),
    ShoppingItem(
      id: 'i-d1',
      name: tr('Zahnpasta', 'Toothpaste'),
      quantity: null,
      checked: false,
      createdAt: _now,
      listId: 'l-drug',
      categoryId: 'cd-care',
      addedBy: mama,
    ),
  ];

  static List<ShoppingTrip> trips() => [
    ShoppingTrip(
      id: 't-2',
      listId: 'l-super',
      finishedAt: DateTime(2026, 10, 8, 17, 40),
      itemCount: tripItems('t-2').length,
    ),
    ShoppingTrip(
      id: 't-1',
      listId: 'l-super',
      finishedAt: DateTime(2026, 10, 3, 10, 5),
      itemCount: tripItems('t-1').length,
    ),
  ];

  /// The items bought on each finished trip; the trip's `itemCount` is the length of its list.
  static List<TripItem> tripItems(String tripId) => switch (tripId) {
    't-2' => [
      TripItem(
        name: tr('Milch', 'Milk'),
        quantity: tr('1,5 %', 'semi-skimmed'),
        count: 2,
      ),
      TripItem(name: tr('Brot', 'Bread'), quantity: null, count: 1),
      TripItem(name: tr('Äpfel', 'Apples'), quantity: null, count: 1),
      TripItem(
        name: tr('Eier', 'Eggs'),
        quantity: tr('10er', 'pack of 10'),
        count: 1,
      ),
      TripItem(name: tr('Käse', 'Cheese'), quantity: null, count: 1),
      TripItem(name: tr('Bananen', 'Bananas'), quantity: null, count: 1),
      TripItem(name: tr('Butter', 'Butter'), quantity: null, count: 1),
      TripItem(name: tr('Joghurt', 'Yoghurt'), quantity: null, count: 2),
      TripItem(name: tr('Nudeln', 'Pasta'), quantity: null, count: 1),
      TripItem(name: tr('Tomaten', 'Tomatoes'), quantity: null, count: 1),
      TripItem(name: tr('Gurke', 'Cucumber'), quantity: null, count: 1),
      TripItem(
        name: tr('Orangensaft', 'Orange juice'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr('Toilettenpapier', 'Toilet paper'),
        quantity: tr('8er', 'pack of 8'),
        count: 1,
      ),
      TripItem(
        name: tr('Kaffee', 'Coffee'),
        quantity: tr('500 g', '500 g'),
        count: 1,
      ),
    ],
    't-1' => [
      TripItem(name: tr('Haferflocken', 'Oats'), quantity: null, count: 1),
      TripItem(name: tr('Reis', 'Rice'), quantity: null, count: 1),
      TripItem(
        name: tr('Hähnchenbrust', 'Chicken breast'),
        quantity: null,
        count: 1,
      ),
      TripItem(name: tr('Paprika', 'Peppers'), quantity: null, count: 3),
      TripItem(name: tr('Zwiebeln', 'Onions'), quantity: null, count: 1),
      TripItem(
        name: tr('Kartoffeln', 'Potatoes'),
        quantity: tr('2 kg', '2 kg'),
        count: 1,
      ),
      TripItem(
        name: tr('Spülmittel', 'Washing-up liquid'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr('Müllbeutel', 'Bin bags'),
        quantity: tr('20er', 'pack of 20'),
        count: 1,
      ),
    ],
    _ => const [],
  };

  static String get kidsTablet => tr('Kinder-iPad', "Kids' iPad");
  static String get kitchenWall => tr('Küche (Wand)', 'Kitchen (wall)');

  static List<DeviceEntry> get devices => [
    DeviceEntry(
      id: 'd-1',
      label: papaPhone,
      deviceClass: DeviceClass.personal,
      register: UiRegister.adult,
      revoked: false,
      lastSeenAt: DateTime(2026, 10, 11, 8, 55),
    ),
    DeviceEntry(
      id: 'd-2',
      label: kidsTablet,
      deviceClass: DeviceClass.shared,
      register: UiRegister.kid,
      revoked: false,
      lastSeenAt: DateTime(2026, 10, 10, 18, 20),
    ),
    DeviceEntry(
      id: 'd-3',
      label: kitchenWall,
      deviceClass: DeviceClass.kiosk,
      register: UiRegister.kiosk,
      revoked: false,
      lastSeenAt: DateTime(2026, 10, 11, 9),
    ),
  ];
}
