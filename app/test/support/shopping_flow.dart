import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/features/shopping/ui/shopping_trip_page.dart';

import 'fakes.dart';

/// The changes the shopping UI asked the sync for, without a server behind them.
class SpyShoppingSync extends ShoppingSync {
  final counts = <({String itemId, int delta})>[];
  final categories = <({String itemId, String? categoryId})>[];
  final specs = <({String itemId, String? text})>[];

  @override
  Future<void> adjustCount({
    required String? actor,
    required String itemId,
    required int delta,
  }) async => counts.add((itemId: itemId, delta: delta));

  @override
  Future<void> setCategory({
    required String? actor,
    required String itemId,
    required String? categoryId,
  }) async => categories.add((itemId: itemId, categoryId: categoryId));

  @override
  Future<void> setSpec({
    required String? actor,
    required String itemId,
    required String? text,
  }) async => specs.add((itemId: itemId, text: text));
}

/// Marks the home shell's navigation: it must be gone while the trip page is open.
const homeNavKey = ValueKey('home-nav');

/// The shopping tab in a stand-in home shell with a navigation bar, and the trip page
/// as its own route on top of it, as in the app's router.
Future<GoRouter> pumpShoppingFlow(
  WidgetTester t,
  List<CatalogEntry> catalog, {
  UiRegister register = UiRegister.adult,
  Size size = const Size(390, 844),
  List<ShoppingItem>? items,
  List<ShoppingCategory> categories = const [],
  ShoppingModeStore? modeStore,
  FakeShoppingRepository? repo,
  bool spy = true,
  Locale locale = const Locale('de'),
}) async {
  final shown = items ?? [item('1', 'Milch'), item('2', 'Brot')];
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: const ShoppingBody(),
          bottomNavigationBar: NavigationBar(
            key: homeNavKey,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.list), label: 'Liste'),
            ],
          ),
        ),
      ),
      GoRoute(
        path: Routes.shoppingTrip,
        builder: (_, _) => const ShoppingTripPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        uiRegisterProvider.overrideWithValue(register),
        shoppingViewProvider.overrideWithValue(
          AsyncData(
            ShoppingView(
              items: shown,
              lists: const [
                ShoppingList(
                  id: 'l1',
                  name: 'Supermarkt',
                  isDefault: true,
                  openCount: 1,
                ),
              ],
              categories: categories,
              catalog: catalog,
              pendingCount: 0,
            ),
          ),
        ),
        if (spy) shoppingSyncProvider.overrideWith(SpyShoppingSync.new),
        shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
        shoppingModeStoreProvider.overrideWithValue(
          modeStore ?? MemoryShoppingModeStore(),
        ),
        shoppingRepositoryProvider.overrideWithValue(
          repo ?? FakeShoppingRepository(shown),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.build(register, Shade.light),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: locale,
        routerConfig: router,
      ),
    ),
  );
  await t.pumpAndSettle();
  return router;
}

ProviderContainer containerOfFlow(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

SpyShoppingSync spyOf(WidgetTester t) =>
    containerOfFlow(t).read(shoppingSyncProvider.notifier) as SpyShoppingSync;
