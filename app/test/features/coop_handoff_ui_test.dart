import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart'
    show localizationsDelegates, supportedLocales;
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/shopping/application/coop_handoff_providers.dart';
import 'package:wuselwall/features/shopping/data/coop_handoff_store.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/coop_settings_page.dart';
import 'package:wuselwall/features/shopping/ui/coop_sheet.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';
import '../support/shopping_flow.dart';
import 'shopping_tiles_test.dart' show entry;

final _de = lookupAppLocalizations(const Locale('de'));

const _sendKey = ValueKey('shopping-coop-send');
const _signInKey = ValueKey('coop-sign-in');
const _connectedKey = ValueKey('coop-connected');
const _disconnectKey = ValueKey('coop-disconnect');

/// A stand-in for the Coop sheet: records what it was asked to push and answers with
/// [outcome] (null = the person closed it). No WebView is ever built.
class FakeCoopLauncher {
  FakeCoopLauncher(this.outcome, {this.onOpen});

  CoopOutcome? outcome;
  Future<void> Function(BuildContext context)? onOpen;
  final calls = <List<HandoffItem>?>[];

  Future<CoopOutcome?> call(
    BuildContext context, {
    List<HandoffItem>? items,
  }) async {
    calls.add(items);
    await onOpen?.call(context);
    return outcome;
  }
}

/// A Coop session ended on this device, as the fake sees it.
class FakeSessionClearer {
  var calls = 0;

  Future<void> call() async => calls++;
}

List<Override> _coop({
  bool supported = true,
  HandoffState? linked,
  FakeCoopLauncher? launcher,
  MemoryCoopHandoffStore? store,
  FakeSessionClearer? clearer,
}) => [
  coopHandoffSupportedProvider.overrideWithValue(supported),
  coopHandoffStoreProvider.overrideWithValue(
    store ?? MemoryCoopHandoffStore(linked),
  ),
  if (launcher != null)
    coopSheetLauncherProvider.overrideWithValue(launcher.call),
  if (clearer != null)
    coopSessionClearerProvider.overrideWithValue(clearer.call),
];

Future<void> _pumpSettings(
  WidgetTester t, {
  required List<Override> overrides,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: const Locale('de'),
        home: const CoopSettingsPage(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  final catalog = [entry('Milch', 9), entry('Brot', 7)];
  const linked = HandoffState();

  group('the planning bar', () {
    Future<void> pump(
      WidgetTester t, {
      bool supported = true,
      HandoffState? link = linked,
      UiRegister register = UiRegister.adult,
      FakeCoopLauncher? launcher,
      List<ShoppingItem>? items,
    }) => pumpShoppingFlow(
      t,
      catalog,
      register: register,
      items: items,
      overrides: _coop(supported: supported, linked: link, launcher: launcher),
    );

    testWidgets('has no Coop button in a build without a WebView', (t) async {
      await pump(t, supported: false);
      expect(find.byKey(_sendKey), findsNothing);
    });

    testWidgets('has no Coop button while Coop is not connected', (t) async {
      await pump(t, link: null);
      expect(find.byKey(_sendKey), findsNothing);
    });

    testWidgets('has the Coop button once connected, on an adult register', (
      t,
    ) async {
      await pump(t);
      expect(find.byKey(_sendKey), findsOneWidget);
      expect(find.byTooltip(_de.coopSend), findsOneWidget);
    });

    testWidgets('has no Coop button on the kid register', (t) async {
      await pump(t, register: UiRegister.kid);
      expect(find.byKey(_sendKey), findsNothing);
    });

    testWidgets('has no Coop button on the wall', (t) async {
      await pump(t, register: UiRegister.kiosk);
      expect(find.byKey(_sendKey), findsNothing);
    });

    testWidgets(
      'shows the button when the link appears after the first frame',
      (t) async {
        final store = MemoryCoopHandoffStore();
        await pumpShoppingFlow(t, catalog, overrides: _coop(store: store));
        expect(find.byKey(_sendKey), findsNothing);
        await containerOfFlow(t).read(coopHandoffProvider.notifier).connect();
        await t.pumpAndSettle();
        expect(find.byKey(_sendKey), findsOneWidget);
      },
    );
  });

  group('sending the list', () {
    Future<FakeCoopLauncher> send(
      WidgetTester t,
      CoopOutcome? outcome, {
      List<ShoppingItem>? items,
    }) async {
      final launcher = FakeCoopLauncher(outcome);
      await pumpShoppingFlow(
        t,
        catalog,
        items: items,
        overrides: _coop(linked: linked, launcher: launcher),
      );
      await t.tap(find.byKey(_sendKey));
      await t.pumpAndSettle();
      return launcher;
    }

    testWidgets('hands the open items to the sheet, not the ticked ones', (
      t,
    ) async {
      final launcher = await send(
        t,
        null,
        items: [
          item('1', 'Milch'),
          item('2', 'Brot', checked: true),
          ShoppingItem(
            id: '3',
            name: 'Eier',
            quantity: 'Bio',
            checked: false,
            createdAt: DateTime(2026, 10, 11),
            count: 2,
          ),
        ],
      );
      expect(launcher.calls, hasLength(1));
      final sent = launcher.calls.single!;
      expect([for (final i in sent) i.id], ['1', '3']);
      expect([for (final i in sent) i.name], ['Milch', 'Eier']);
      expect([for (final i in sent) i.label], ['Milch', '2× Eier (Bio)']);
    });

    testWidgets('says how many items are on the Coop list', (t) async {
      await send(
        t,
        const CoopPushed(HandoffResult(sent: 2, total: 2, failed: 0)),
      );
      final text = _de.coopPushed(2, 'WuselWall');
      expect(find.text(text), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('says so when only some items made it', (t) async {
      await send(
        t,
        const CoopPushed(HandoffResult(sent: 1, total: 2, failed: 1)),
      );
      expect(find.text(_de.coopPushedPartly(1, 2)), findsOneWidget);
    });

    testWidgets('says so when Coop could not be reached', (t) async {
      await send(t, const CoopFailed());
      expect(find.text(_de.coopPushFailed), findsOneWidget);
    });

    testWidgets('shows nothing when the sheet was closed', (t) async {
      final launcher = await send(t, null);
      expect(launcher.calls, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a later send shows its own line', (t) async {
      final launcher = await send(t, const CoopFailed());
      expect(find.text(_de.coopPushFailed), findsOneWidget);
      // The line covers the bar until it goes away by itself.
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      launcher.outcome = const CoopPushed(
        HandoffResult(sent: 2, total: 2, failed: 0),
      );
      await t.tap(find.byKey(_sendKey));
      await t.pumpAndSettle();
      expect(find.text(_de.coopPushFailed), findsNothing);
      expect(find.text(_de.coopPushed(2, 'WuselWall')), findsOneWidget);
    });
  });

  group('the settings page', () {
    testWidgets('names the list and offers to sign in while not connected', (
      t,
    ) async {
      await _pumpSettings(t, overrides: _coop());
      expect(find.text(_de.coopIntro('WuselWall')), findsOneWidget);
      expect(find.byKey(_signInKey), findsOneWidget);
      expect(find.byKey(_connectedKey), findsNothing);
      expect(find.byKey(_disconnectKey), findsNothing);
    });

    testWidgets('signing in opens the sheet without items and connects', (
      t,
    ) async {
      final store = MemoryCoopHandoffStore();
      final launcher = FakeCoopLauncher(
        const CoopConnected(),
        onOpen: (context) =>
            ProviderScope.containerOf(context)
                .read(coopHandoffProvider.notifier)
                .connect(),
      );
      await _pumpSettings(
        t,
        overrides: _coop(store: store, launcher: launcher),
      );
      await t.tap(find.byKey(_signInKey));
      await t.pumpAndSettle();

      expect(launcher.calls, [null]);
      expect(store.state, isNotNull);
      expect(find.byKey(_connectedKey), findsOneWidget);
      expect(find.byKey(_signInKey), findsNothing);
      expect(find.byKey(_disconnectKey), findsOneWidget);
      expect(find.text(_de.coopSignedIn), findsOneWidget);
    });

    testWidgets('closing the sheet leaves the page as it was', (t) async {
      final launcher = FakeCoopLauncher(null);
      await _pumpSettings(t, overrides: _coop(launcher: launcher));
      await t.tap(find.byKey(_signInKey));
      await t.pumpAndSettle();
      expect(launcher.calls, [null]);
      expect(find.byKey(_signInKey), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed sign-in says so and stays signed out', (t) async {
      await _pumpSettings(
        t,
        overrides: _coop(launcher: FakeCoopLauncher(const CoopFailed())),
      );
      await t.tap(find.byKey(_signInKey));
      await t.pumpAndSettle();
      expect(find.text(_de.coopPushFailed), findsOneWidget);
      expect(find.byKey(_signInKey), findsOneWidget);
    });

    testWidgets('shows the link and the last push when connected', (t) async {
      await _pumpSettings(
        t,
        overrides: _coop(
          linked: HandoffState(
            lastPushAt: DateTime(2026, 10, 30),
            lastPushCount: 3,
          ),
        ),
      );
      expect(find.byKey(_connectedKey), findsOneWidget);
      expect(find.byKey(_signInKey), findsNothing);
      expect(find.textContaining(_de.coopLastPush(3)), findsOneWidget);
    });

    testWidgets('disconnecting forgets the link and the Coop session', (
      t,
    ) async {
      final store = MemoryCoopHandoffStore(linked);
      final clearer = FakeSessionClearer();
      await _pumpSettings(
        t,
        overrides: _coop(store: store, clearer: clearer),
      );
      expect(find.byKey(_connectedKey), findsOneWidget);

      await t.tap(find.byKey(_disconnectKey));
      await t.pumpAndSettle();

      expect(store.state, isNull);
      expect(clearer.calls, 1);
      expect(find.byKey(_signInKey), findsOneWidget);
      expect(find.byKey(_connectedKey), findsNothing);
      expect(find.text(_de.coopSignedOut), findsOneWidget);
    });
  });
}
