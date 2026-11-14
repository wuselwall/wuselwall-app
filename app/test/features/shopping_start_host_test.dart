import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/app_locale_provider.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/ui/shopping_start_host.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/notice.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_notices.dart';
import '../support/fake_notifications.dart';
import '../support/fakes.dart';

/// The host that says "Mama geht einkaufen" the moment the server's notice arrives
/// (specs/07 "Telling the others"): banner in front, local notification out of sight.

final _de = AppLocalizationsDe();

AppNotice _trip(String run, {String name = 'Mama', String list = 'Garten'}) =>
    AppNotice(
      key: 'shopping:$run',
      kind: NoticeKind.shopping,
      name: name,
      listId: 'list-$run',
      listName: list,
      at: DateTime(2026, 11, 14, 10),
    );

Finder _banner(AppNotice trip) =>
    find.byKey(ValueKey('shopping-start-${trip.key}'));

/// Notices that depend on who asks, as the server's do.
class _PerActorNotices extends FakeNoticesRepository {
  _PerActorNotices(this.byActor);

  final Map<String, List<AppNotice>> byActor;

  @override
  Future<Result<List<AppNotice>>> notices({required String actor}) async {
    await super.notices(actor: actor);
    return Ok(List.of(byActor[actor] ?? const []));
  }
}

class _Host {
  _Host(this.container, this.notices, this.scheduler, this.router);

  final ProviderContainer container;
  final FakeNoticesRepository notices;
  final FakeNotificationScheduler scheduler;
  final GoRouter router;

  /// A fetch of the notices, as a realtime event or a refresh does.
  Future<void> refetch(WidgetTester t) async {
    container.invalidate(noticesProvider);
    await t.pumpAndSettle();
  }

  /// The banner goes away, as it does by itself after ten seconds.
  Future<void> hideBanner(WidgetTester t) async {
    ScaffoldMessenger.of(t.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await t.pumpAndSettle();
  }
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  Future<_Host> pumpHost(
    WidgetTester t, {
    List<AppNotice> notices = const [],
    DeviceInfo? current,
    FakeNotificationScheduler? scheduler,
    List<String>? serverFeatures,
    String initialLocation = Routes.home,
    FakeNoticesRepository? repository,
  }) async {
    final repo = repository ?? FakeNoticesRepository(notices);
    final fake = scheduler ?? FakeNotificationScheduler();
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const Scaffold(body: Text('settings')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: 'test',
              supabaseUrl: 'http://localhost',
              supabasePublishableKey: 'key',
              server: serverFeatures == null
                  ? null
                  : ServerInfo(
                      supabaseUrl: Uri.parse('https://example.org'),
                      publishableKey: 'key',
                      apiVersion: 1,
                      minAppVersion: '1.0.0',
                      features: serverFeatures,
                    ),
            ),
          ),
          deviceProvider.overrideWithValue(AsyncData(current ?? device())),
          appLocaleProvider.overrideWithValue(const Locale('de')),
          notificationSchedulerProvider.overrideWithValue(fake),
          noticesRepositoryProvider.overrideWithValue(repo),
          routerProvider.overrideWithValue(router),
          householdInvalidationsProvider.overrideWith(
            (ref, id) => const Stream<Invalidation>.empty(),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          locale: const Locale('de'),
          routerConfig: router,
          builder: (_, child) => ShoppingStartHost(child: child!),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    );
    await t.pumpAndSettle();
    return _Host(container, repo, fake, router);
  }

  void setLifecycle(WidgetTester t, AppLifecycleState state) =>
      t.binding.handleAppLifecycleStateChanged(state);

  group('in front', () {
    testWidgets('a trip that was already there is not announced', (t) async {
      final scheduler = FakeNotificationScheduler();
      final host = await pumpHost(
        t,
        notices: [_trip('1')],
        scheduler: scheduler,
      );

      expect(host.notices.fetches, greaterThan(0));
      expect(find.byType(SnackBar), findsNothing);
      expect(scheduler.shown, isEmpty);

      // Not on a later fetch of the same list either.
      await host.refetch(t);
      expect(find.byType(SnackBar), findsNothing);
      expect(scheduler.shown, isEmpty);
    });

    testWidgets('a trip that appears later shows the banner with "Zur Liste"', (
      t,
    ) async {
      final scheduler = FakeNotificationScheduler();
      final host = await pumpHost(t, scheduler: scheduler);
      final trip = _trip('1');
      host.notices.add(trip);
      await host.refetch(t);

      expect(_banner(trip), findsOneWidget);
      expect(
        find.descendant(
          of: _banner(trip),
          matching: find.text(_de.todayNoticeShopping('Mama', 'Garten')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _banner(trip),
          matching: find.text(_de.todayNoticeShoppingList),
        ),
        findsOneWidget,
      );
      // In front, no notification as well.
      expect(scheduler.shown, isEmpty);
    });

    testWidgets(
      '"Zur Liste" goes home and opens that list on the Shopping tab',
      (t) async {
        final host = await pumpHost(t, initialLocation: Routes.settings);
        expect(find.text('settings'), findsOneWidget);
        final trip = _trip('1');
        host.notices.add(trip);
        await host.refetch(t);

        await t.tap(find.text(_de.todayNoticeShoppingList));
        await t.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(host.container.read(homeTabProvider), HomeTab.shopping);
        expect(host.container.read(selectedListIdProvider), 'list-1');
      },
    );

    testWidgets('the same trip delivered again is announced once', (t) async {
      final host = await pumpHost(t);
      final trip = _trip('1');
      host.notices.add(trip);
      await host.refetch(t);
      expect(_banner(trip), findsOneWidget);
      await host.hideBanner(t);
      expect(find.byType(SnackBar), findsNothing);

      // A refetch, and the same key twice in one answer.
      await host.refetch(t);
      host.notices.add(trip);
      await host.refetch(t);

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'another trip is announced on its own and replaces the banner',
      (t) async {
        final host = await pumpHost(t);
        final first = _trip('1');
        final second = _trip('2', name: 'Papa', list: 'Baumarkt');
        host.notices.add(first);
        await host.refetch(t);
        host.notices.add(second);
        await host.refetch(t);

        expect(_banner(second), findsOneWidget);
        expect(_banner(first), findsNothing);
        expect(
          find.text(_de.todayNoticeShopping('Papa', 'Baumarkt')),
          findsOneWidget,
        );
      },
    );

    testWidgets('other kinds of notice are not announced', (t) async {
      final host = await pumpHost(t);
      host.notices.add(
        AppNotice(
          key: 'join:1',
          kind: NoticeKind.join,
          name: 'Julia',
          at: DateTime(2026, 11, 14, 10),
        ),
      );
      await host.refetch(t);

      expect(find.byType(SnackBar), findsNothing);
      expect(host.scheduler.shown, isEmpty);
    });
  });

  group('out of sight', () {
    testWidgets('a personal phone with permission shows one notification', (
      t,
    ) async {
      final scheduler = FakeNotificationScheduler();
      final host = await pumpHost(t, scheduler: scheduler);
      setLifecycle(t, AppLifecycleState.paused);
      final trip = _trip('1');
      host.notices.add(trip);
      await host.refetch(t);

      expect(scheduler.shown, hasLength(1));
      final shown = scheduler.shown.single;
      expect(shown.id, shoppingStartNotificationId(trip.key));
      expect(shown.title, _de.shoppingStartNotifyTitle('Mama'));
      expect(shown.body, _de.shoppingStartNotifyBody('Garten'));
      expect(find.byType(SnackBar), findsNothing);

      // Again delivered: still one. And back in front: no banner on top of it.
      await host.refetch(t);
      host.notices.add(trip);
      await host.refetch(t);
      setLifecycle(t, AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(scheduler.shown, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'without permission nothing is shown, and the banner comes back with the app',
      (t) async {
        final scheduler = FakeNotificationScheduler(granted: false);
        final host = await pumpHost(t, scheduler: scheduler);
        setLifecycle(t, AppLifecycleState.paused);
        final trip = _trip('1');
        host.notices.add(trip);
        await host.refetch(t);

        expect(scheduler.shown, isEmpty);
        expect(find.byType(SnackBar), findsNothing);

        final fetched = host.notices.fetches;
        setLifecycle(t, AppLifecycleState.resumed);
        await t.pumpAndSettle();

        // The list was fetched again, and the trip still runs.
        expect(host.notices.fetches, greaterThan(fetched));
        expect(_banner(trip), findsOneWidget);
        expect(scheduler.shown, isEmpty);
      },
    );

    testWidgets('a trip that ended meanwhile is not announced when back', (
      t,
    ) async {
      final scheduler = FakeNotificationScheduler(granted: false);
      final host = await pumpHost(t, scheduler: scheduler);
      setLifecycle(t, AppLifecycleState.paused);
      final trip = _trip('1');
      host.notices.add(trip);
      await host.refetch(t);

      host.notices.remove(trip.key);
      setLifecycle(t, AppLifecycleState.resumed);
      await t.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(scheduler.shown, isEmpty);
      // And it does not come with a later fetch.
      await host.refetch(t);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a shared device never shows a notification, only the banner', (
      t,
    ) async {
      final scheduler = FakeNotificationScheduler();
      final host = await pumpHost(
        t,
        scheduler: scheduler,
        current: device(deviceClass: DeviceClass.shared),
      );
      host.container.read(actingProfileProvider.notifier).select(guardianId);
      await t.pumpAndSettle();
      setLifecycle(t, AppLifecycleState.paused);
      final trip = _trip('1');
      host.notices.add(trip);
      await host.refetch(t);
      expect(scheduler.shown, isEmpty);

      setLifecycle(t, AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_banner(trip), findsOneWidget);
      expect(scheduler.shown, isEmpty);
    });

    testWidgets('a phone that cannot show notifications waits for the banner', (
      t,
    ) async {
      final scheduler = FakeNotificationScheduler(available: false);
      final host = await pumpHost(t, scheduler: scheduler);
      setLifecycle(t, AppLifecycleState.paused);
      final trip = _trip('1');
      host.notices.add(trip);
      await host.refetch(t);
      expect(scheduler.shown, isEmpty);

      setLifecycle(t, AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_banner(trip), findsOneWidget);
    });

    testWidgets('coming back with nothing waiting fetches nothing more', (
      t,
    ) async {
      final host = await pumpHost(t);
      setLifecycle(t, AppLifecycleState.paused);
      await t.pumpAndSettle();
      final fetched = host.notices.fetches;
      setLifecycle(t, AppLifecycleState.resumed);
      await t.pumpAndSettle();

      expect(host.notices.fetches, fetched);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('who is at the device', () {
    testWidgets('another person at a shared device starts from what is there', (
      t,
    ) async {
      final host = await pumpHost(
        t,
        notices: [_trip('1')],
        current: device(deviceClass: DeviceClass.shared),
      );
      final acting = host.container.read(actingProfileProvider.notifier);
      acting.select(guardianId);
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      final later = _trip('2');
      host.notices.add(later);
      await host.refetch(t);
      expect(_banner(later), findsOneWidget);
      await host.hideBanner(t);

      // Somebody else takes the phone: both trips are theirs to find on Today.
      acting.select(kidId);
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await host.refetch(t);
      expect(find.byType(SnackBar), findsNothing);

      // But a third one is announced to them.
      final third = _trip('3');
      host.notices.add(third);
      await host.refetch(t);
      expect(_banner(third), findsOneWidget);
    });
  });

  group('who is at the device, with notices of their own', () {
    testWidgets(
      'the list of the person who takes the device is the baseline, not the last one\'s',
      (t) async {
        final mine = _trip('mine');
        final theirs = _trip('theirs', name: 'Papa');
        final host = await pumpHost(
          t,
          current: device(deviceClass: DeviceClass.shared),
          repository: _PerActorNotices({
            guardianId: [mine],
            kidId: [theirs],
          }),
        );
        final acting = host.container.read(actingProfileProvider.notifier);
        acting.select(guardianId);
        await t.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);

        acting.select(kidId);
        await t.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });

  group('where nothing is announced', () {
    testWidgets('the kid register never asks for the notices', (t) async {
      final host = await pumpHost(
        t,
        notices: [_trip('1')],
        current: device(register: UiRegister.kid),
      );
      host.container.invalidate(noticesProvider);
      await t.pumpAndSettle();
      expect(host.notices.fetches, 0);

      host.notices.add(_trip('2'));
      await t.pumpAndSettle();
      expect(host.notices.fetches, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(host.scheduler.shown, isEmpty);
    });

    testWidgets('a server without the feature never asks either', (t) async {
      final host = await pumpHost(
        t,
        notices: [_trip('1')],
        serverFeatures: const [],
      );
      expect(host.notices.fetches, 0);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
