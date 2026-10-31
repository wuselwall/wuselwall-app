import 'package:flutter/painting.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Invented family for the user documentation's screenshots (`lib/main_demo.dart`).
/// Nothing here is real data.
abstract final class DemoData {
  static const papa = 'p-papa';
  static const mama = 'p-mama';
  static const daughter = 'p-daughter';
  static const son = 'p-son';

  /// The family's names in all shipped languages, by language code.
  static const _names = {
    papa: {'de': 'Thomas', 'en': 'David', 'fr': 'Thomas', 'es': 'David'},
    mama: {'de': 'Julia', 'en': 'Sarah', 'fr': 'Julie', 'es': 'Sara'},
    daughter: {'de': 'Emma', 'en': 'Olivia', 'fr': 'Emma', 'es': 'Olivia'},
    son: {'de': 'Paul', 'en': 'Jack', 'fr': 'Paul', 'es': 'Pablo'},
  };

  static var _languageCode = 'de';

  /// The demo's language (`de`, `en`, `fr`, `es`); set by [useLanguageOf].
  static String get languageCode => _languageCode;

  /// Whether the demo runs in English; kept for the existing English demo tables.
  static bool get english => _languageCode == 'en';

  /// Picks the language as MaterialApp does from the device's [preferred] locales and
  /// app.dart's `supportedLocales`: the first supported one, German otherwise.
  static void useLanguageOf(List<Locale> preferred) {
    _languageCode = resolveAppLocale(preferred).languageCode;
  }

  /// The display name of the member [id].
  static String name(String id) => _names[id]![_languageCode]!;

  /// [text] in the demo's language: [text] is a map of language code to translation.
  /// German is the key of every source string, so German never needs a table.
  static String tr(Map<String, String> text) =>
      text[_languageCode] ?? text['de']!;

  /// German [de], English [en], French [fr], Spanish [es]: all of the demo's content
  /// speaks the app's language, not only the names.
  static String tr4(String de, String en, String fr, String es) =>
      tr({'de': de, 'en': en, 'fr': fr, 'es': es});

  /// The father's phone, as the device list shows it.
  static String get papaPhone => switch (_languageCode) {
    'de' => '${name(papa)}’ iPhone',
    'fr' => 'iPhone de ${name(papa)}',
    'es' => 'iPhone de ${name(papa)}',
    _ => "${name(papa)}'s iPhone",
  };

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
      hasAccount: false,
      // Three days away, so the demo counts down to it (specs/27 "Vorfreude").
      birthday: _inDays(3, yearsAgo: 9),
    ),
    Member(
      id: son,
      displayName: name(son),
      color: Color(0xFF08737F),
      role: Role.member,
      active: true,
      isChild: true,
      hasAccount: false,
      birthday: _inDays(140, yearsAgo: 7),
    ),
  ];

  /// A birthday [days] from today, [yearsAgo] years back.
  static DateTime _inDays(int days, {required int yearsAgo}) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day + days);
    return DateTime(d.year - yearsAgo, d.month, d.day);
  }

  static List<(String, String, bool)> get lists => [
    (
      'l-super',
      tr4('Supermarkt', 'Supermarket', 'Supermarché', 'Supermercado'),
      true,
    ),
    ('l-drug', tr4('Drogerie', 'Pharmacy', 'Droguerie', 'Droguería'), false),
    (
      'l-hardware',
      tr4('Baumarkt', 'Hardware store', 'Magasin de bricolage', 'Ferretería'),
      false,
    ),
  ];

  static const superKeys = [
    'produce',
    'bakery',
    'dairy',
    'meat_fish',
    'pantry',
    'snacks',
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

  /// (name, category key, purchases, icon key) — what the household has bought before.
  /// The icon key is the one the server picks from the name (app.catalog_icon_for).
  static List<(String, String, int, String)> get _catalogue => [
    (tr4('Milch', 'Milk', 'Lait', 'Leche'), 'dairy', 42, 'milk'),
    (tr4('Brot', 'Bread', 'Pain', 'Pan'), 'bakery', 35, 'bread'),
    (tr4('Bananen', 'Bananas', 'Bananes', 'Plátanos'), 'produce', 31, 'banana'),
    (tr4('Äpfel', 'Apples', 'Pommes', 'Manzanas'), 'produce', 24, 'apple'),
    (tr4('Butter', 'Butter', 'Beurre', 'Mantequilla'), 'dairy', 22, 'butter'),
    (tr4('Eier', 'Eggs', 'Œufs', 'Huevos'), 'dairy', 21, 'egg'),
    (tr4('Nudeln', 'Pasta', 'Pâtes', 'Pasta'), 'pantry', 19, 'pasta'),
    (tr4('Joghurt', 'Yoghurt', 'Yaourt', 'Yogur'), 'dairy', 18, 'bowl'),
    (tr4('Tomaten', 'Tomatoes', 'Tomates', 'Tomates'), 'produce', 17, 'tomato'),
    (tr4('Käse', 'Cheese', 'Fromage', 'Queso'), 'dairy', 16, 'cheese'),
    (
      tr4('Gurke', 'Cucumber', 'Concombre', 'Pepino'),
      'produce',
      12,
      'cucumber',
    ),
    (tr4('Reis', 'Rice', 'Riz', 'Arroz'), 'pantry', 11, 'rice'),
    (
      tr4('Orangensaft', 'Orange juice', 'Jus d’orange', 'Zumo de naranja'),
      'drinks',
      9,
      'juice',
    ),
    (
      tr4(
        'Toilettenpapier',
        'Toilet paper',
        'Papier toilette',
        'Papel higiénico',
      ),
      'household',
      8,
      'toilet_paper',
    ),
    (
      tr4('Gummibärchen', 'Gummy bears', 'Oursons en gomme', 'Gominolas'),
      'pantry',
      7,
      'candy',
    ),
    (
      tr4('Kartoffeln', 'Potatoes', 'Pommes de terre', 'Patatas'),
      'produce',
      7,
      'potato',
    ),
    (tr4('Chips', 'Crisps', 'Chips', 'Patatas fritas'), 'snacks', 6, 'fries'),
  ];

  static List<CatalogEntry> catalogue() => [
    for (final (i, (name, cat, n, icon)) in _catalogue.indexed)
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
        iconKey: icon,
      ),
  ];

  /// The pasta, which came from two of the week's meals.
  static String get pasta => tr4('Nudeln', 'Pasta', 'Pâtes', 'Pasta');

  /// (name, category key, count, spec, added by, ticked)
  static List<(String, String, int, String?, String, bool)> get _items => [
    (
      tr4('Bananen', 'Bananas', 'Bananes', 'Plátanos'),
      'produce',
      1,
      null,
      daughter,
      false,
    ),
    (
      tr4('Gurke', 'Cucumber', 'Concombre', 'Pepino'),
      'produce',
      2,
      null,
      mama,
      false,
    ),
    (
      tr4('Brot', 'Bread', 'Pain', 'Pan'),
      'bakery',
      1,
      tr4('Vollkorn', 'Wholemeal', 'Complet', 'Integral'),
      papa,
      false,
    ),
    (
      tr4('Milch', 'Milk', 'Lait', 'Leche'),
      'dairy',
      2,
      tr4('1,5 %', 'semi-skimmed', 'demi-écrémé', 'semidesnatada'),
      papa,
      false,
    ),
    (
      tr4('Joghurt', 'Yoghurt', 'Yaourt', 'Yogur'),
      'dairy',
      1,
      tr4('Natur, 500 g', 'plain, 500 g', 'nature, 500 g', 'natural, 500 g'),
      mama,
      false,
    ),
    (pasta, 'pantry', 1, null, son, false),
    (
      tr4('Gummibärchen', 'Gummy bears', 'Oursons en gomme', 'Gominolas'),
      'pantry',
      1,
      null,
      son,
      false,
    ),
    (
      tr4('Chips', 'Crisps', 'Chips', 'Patatas fritas'),
      'snacks',
      1,
      null,
      daughter,
      false,
    ),
    (
      tr4('Orangensaft', 'Orange juice', 'Jus d’orange', 'Zumo de naranja'),
      'drinks',
      1,
      null,
      mama,
      true,
    ),
    (
      tr4('Butter', 'Butter', 'Beurre', 'Mantequilla'),
      'dairy',
      1,
      null,
      papa,
      true,
    ),
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
      name: tr4('Zahnpasta', 'Toothpaste', 'Dentifrice', 'Pasta de dientes'),
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
        name: tr4('Milch', 'Milk', 'Lait', 'Leche'),
        quantity: tr4('1,5 %', 'semi-skimmed', 'demi-écrémé', 'semidesnatada'),
        count: 2,
      ),
      TripItem(
        name: tr4('Brot', 'Bread', 'Pain', 'Pan'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Äpfel', 'Apples', 'Pommes', 'Manzanas'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Eier', 'Eggs', 'Œufs', 'Huevos'),
        quantity: tr4('10er', 'pack of 10', 'boîte de 10', 'paquete de 10'),
        count: 1,
      ),
      TripItem(
        name: tr4('Käse', 'Cheese', 'Fromage', 'Queso'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Bananen', 'Bananas', 'Bananes', 'Plátanos'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Butter', 'Butter', 'Beurre', 'Mantequilla'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Joghurt', 'Yoghurt', 'Yaourt', 'Yogur'),
        quantity: null,
        count: 2,
      ),
      TripItem(
        name: tr4('Nudeln', 'Pasta', 'Pâtes', 'Pasta'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Tomaten', 'Tomatoes', 'Tomates', 'Tomates'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Gurke', 'Cucumber', 'Concombre', 'Pepino'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4(
          'Orangensaft',
          'Orange juice',
          'Jus d’orange',
          'Zumo de naranja',
        ),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4(
          'Toilettenpapier',
          'Toilet paper',
          'Papier toilette',
          'Papel higiénico',
        ),
        quantity: tr4('8er', 'pack of 8', 'paquet de 8', 'paquete de 8'),
        count: 1,
      ),
      TripItem(
        name: tr4('Kaffee', 'Coffee', 'Café', 'Café'),
        quantity: tr4('500 g', '500 g', '500 g', '500 g'),
        count: 1,
      ),
    ],
    't-1' => [
      TripItem(
        name: tr4('Haferflocken', 'Oats', 'Flocons d’avoine', 'Avena'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Reis', 'Rice', 'Riz', 'Arroz'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4(
          'Hähnchenbrust',
          'Chicken breast',
          'Blanc de poulet',
          'Pechuga de pollo',
        ),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Paprika', 'Peppers', 'Poivrons', 'Pimientos'),
        quantity: null,
        count: 3,
      ),
      TripItem(
        name: tr4('Zwiebeln', 'Onions', 'Oignons', 'Cebollas'),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4('Kartoffeln', 'Potatoes', 'Pommes de terre', 'Patatas'),
        quantity: tr4('2 kg', '2 kg', '2 kg', '2 kg'),
        count: 1,
      ),
      TripItem(
        name: tr4(
          'Spülmittel',
          'Washing-up liquid',
          'Liquide vaisselle',
          'Lavavajillas',
        ),
        quantity: null,
        count: 1,
      ),
      TripItem(
        name: tr4(
          'Müllbeutel',
          'Bin bags',
          'Sacs poubelle',
          'Bolsas de basura',
        ),
        quantity: tr4('20er', 'pack of 20', 'paquet de 20', 'paquete de 20'),
        count: 1,
      ),
    ],
    _ => const [],
  };

  static String get kidsTablet =>
      tr4('Kinder-iPad', "Kids' iPad", 'iPad des enfants', 'iPad de los niños');
  static String get kitchenWall =>
      tr4('Küche (Wand)', 'Kitchen (wall)', 'Cuisine (mur)', 'Cocina (pared)');

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
