import 'package:flutter/painting.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Invented family for the user documentation's screenshots (`lib/main_demo.dart`).
/// Nothing here is real data.
abstract final class DemoData {
  static const papa = 'p-papa';
  static const mama = 'p-mama';
  static const lotta = 'p-lotta';
  static const hanna = 'p-hanna';

  static const members = [
    Member(
      id: papa,
      displayName: 'Lukas',
      color: Color(0xFFC2255C),
      role: Role.guardian,
      active: true,
    ),
    Member(
      id: mama,
      displayName: 'Sabine',
      color: Color(0xFF9A5300),
      role: Role.guardian,
      active: true,
    ),
    Member(
      id: lotta,
      displayName: 'Lotta',
      color: Color(0xFF7B3FE4),
      role: Role.member,
      active: true,
      isChild: true,
    ),
    Member(
      id: hanna,
      displayName: 'Hanna',
      color: Color(0xFF08737F),
      role: Role.member,
      active: true,
      isChild: true,
    ),
  ];

  static const lists = [
    ('l-super', 'Supermarkt', true),
    ('l-drug', 'Drogerie', false),
    ('l-hardware', 'Baumarkt', false),
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
  static const _catalogue = [
    ('Milch', 'dairy', 42),
    ('Brot', 'bakery', 35),
    ('Bananen', 'produce', 31),
    ('Äpfel', 'produce', 24),
    ('Butter', 'dairy', 22),
    ('Eier', 'dairy', 21),
    ('Nudeln', 'pantry', 19),
    ('Joghurt', 'dairy', 18),
    ('Tomaten', 'produce', 17),
    ('Käse', 'dairy', 16),
    ('Gurke', 'produce', 12),
    ('Reis', 'pantry', 11),
    ('Orangensaft', 'drinks', 9),
    ('Toilettenpapier', 'household', 8),
    ('Gummibärchen', 'pantry', 7),
    ('Kartoffeln', 'produce', 7),
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

  /// (name, category key, count, spec, added by, ticked)
  static const _items = [
    ('Bananen', 'produce', 1, null, lotta, false),
    ('Gurke', 'produce', 2, null, mama, false),
    ('Brot', 'bakery', 1, 'Vollkorn', papa, false),
    ('Milch', 'dairy', 2, '1,5 %', papa, false),
    ('Joghurt', 'dairy', 1, 'Natur, 500 g', mama, false),
    ('Nudeln', 'pantry', 1, null, hanna, false),
    ('Gummibärchen', 'pantry', 1, null, hanna, false),
    ('Orangensaft', 'drinks', 1, null, mama, true),
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
        sourceMealEntryIds: name == 'Nudeln'
            ? const ['demo-src-nudel', 'demo-src-pesto']
            : const [],
      ),
    ShoppingItem(
      id: 'i-d1',
      name: 'Zahnpasta',
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
      itemCount: 14,
    ),
    ShoppingTrip(
      id: 't-1',
      listId: 'l-super',
      finishedAt: DateTime(2026, 10, 3, 10, 5),
      itemCount: 22,
    ),
  ];

  static const tripItems = [
    TripItem(name: 'Milch', quantity: '1,5 %', count: 2),
    TripItem(name: 'Brot', quantity: null, count: 1),
    TripItem(name: 'Äpfel', quantity: null, count: 1),
    TripItem(name: 'Eier', quantity: '10er', count: 1),
    TripItem(name: 'Käse', quantity: null, count: 1),
  ];

  static final devices = [
    DeviceEntry(
      id: 'd-1',
      label: 'Lukas’ iPhone',
      deviceClass: DeviceClass.personal,
      register: UiRegister.adult,
      revoked: false,
      lastSeenAt: DateTime(2026, 10, 11, 8, 55),
    ),
    DeviceEntry(
      id: 'd-2',
      label: 'Kinder-iPad',
      deviceClass: DeviceClass.shared,
      register: UiRegister.kid,
      revoked: false,
      lastSeenAt: DateTime(2026, 10, 10, 18, 20),
    ),
    DeviceEntry(
      id: 'd-3',
      label: 'Küche (Wand)',
      deviceClass: DeviceClass.kiosk,
      register: UiRegister.kiosk,
      revoked: false,
      lastSeenAt: DateTime(2026, 10, 11, 9),
    ),
  ];
}
