import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

import '../support/fakes.dart';
import 'shopping_tiles_test.dart' show pumpBody;

ShoppingCategory category(String id, String name, int sortOrder) =>
    ShoppingCategory(
      id: id,
      listId: 'l1',
      key: null,
      name: name,
      sortOrder: sortOrder,
    );

void main() {
  test('lists and categories are asked for in ascending sort order', () async {
    final asked = <String, String?>{};
    final client = MockClient((req) async {
      asked[req.url.path.split('/').last] = req.url.queryParameters['order'];
      return http.Response(
        jsonEncode(const <Object?>[]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: req,
      );
    });
    final repository = ShoppingRepository(
      ApiClient(
        SupabaseClient(
          'http://localhost:54321',
          'anon-key',
          httpClient: client,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
    );
    await repository.lists();
    await repository.categories();
    expect(asked['shopping_lists'], startsWith('sort_order.asc'));
    expect(asked['shopping_categories'], startsWith('sort_order.asc'));
  });

  test('a list from an older mirror, without sort_order, still reads', () {
    final list = ShoppingList.fromJson(const {
      'id': 'l1',
      'name': 'Supermarkt',
      'is_default': true,
      'open_count': 2,
    });
    expect(list.sortOrder, 0);
    expect(ShoppingList.fromJson(list.toJson()).sortOrder, 0);
    expect(
      ShoppingList.fromJson({...list.toJson(), 'sort_order': 20}).sortOrder,
      20,
    );
  });

  testWidgets(
    'category headers follow sortOrder, whatever order they arrive in',
    (t) async {
      await pumpBody(
        t,
        const [],
        register: UiRegister.adult,
        size: const Size(390, 1200),
        categories: [
          category('c3', 'Getränke', 30),
          category('c1', 'Obst', 10),
          category('c2', 'Brot', 20),
        ],
        items: [
          item('1', 'Wasser').copyWith(categoryId: 'c3'),
          item('2', 'Äpfel').copyWith(categoryId: 'c1'),
          item('3', 'Roggenbrot').copyWith(categoryId: 'c2'),
        ],
      );
      final tops = [
        for (final n in ['Obst', 'Brot', 'Getränke'])
          t.getTopLeft(find.text(n)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
    },
  );

  testWidgets('the list chips follow sortOrder too', (t) async {
    await pumpBody(
      t,
      const [],
      register: UiRegister.adult,
      size: const Size(390, 844),
      lists: const [
        ShoppingList(
          id: 'l2',
          name: 'Drogerie',
          isDefault: false,
          openCount: 0,
          sortOrder: 20,
        ),
        ShoppingList(
          id: 'l1',
          name: 'Supermarkt',
          isDefault: true,
          openCount: 0,
          sortOrder: 10,
        ),
      ],
    );
    expect(
      t.getTopLeft(find.text('Supermarkt')).dx,
      lessThan(t.getTopLeft(find.text('Drogerie')).dx),
    );
  });
}
