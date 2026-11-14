import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/notice.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';
import 'package:wuselwall/l10n/generated/app_localizations_en.dart';

import '../support/fake_notices.dart';
import '../support/fake_tasks.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();
final _en = AppLocalizationsEn();

final _joined = AppNotice(
  key: 'join:7',
  kind: NoticeKind.join,
  name: 'Julia',
  at: DateTime(2026, 10, 15, 9),
);
final _signIn = AppNotice(
  key: 'signin:9',
  kind: NoticeKind.signIn,
  name: 'Daniels iPhone',
  at: DateTime(2026, 10, 15, 10),
);
final _mfaResetMine = AppNotice(
  key: 'mfa_reset:11',
  kind: NoticeKind.mfaReset,
  name: 'Mama',
  profileId: guardianId,
  at: DateTime(2026, 10, 15, 11),
);
final _codeForAnna = AppNotice(
  key: 'password_reset_issued:12',
  kind: NoticeKind.passwordResetIssued,
  name: 'Mama',
  profileId: kidId,
  at: DateTime(2026, 10, 15, 12),
);

final _shopping = AppNotice(
  key: 'shopping:run-1',
  kind: NoticeKind.shopping,
  name: 'Mama',
  listId: 'l-garden',
  listName: 'Baumarkt',
  at: DateTime(2026, 10, 15, 13),
);

void main() {
  group('AppNotice.fromJson', () {
    test('a shopping trip reads its list from data', () {
      final notice = AppNotice.fromJson({
        'key': 'shopping:r1',
        'kind': 'shopping',
        'name': 'Mama',
        'at': '2026-10-15T07:00:00+00:00',
        'data': {'list_id': 'l1', 'list_name': 'Supermarkt'},
      })!;
      expect(notice.kind, NoticeKind.shopping);
      expect(notice.name, 'Mama');
      expect(notice.listId, 'l1');
      expect(notice.listName, 'Supermarkt');
    });

    test('another kind has no data, and no list', () {
      final notice = AppNotice.fromJson({
        'key': 'join:1',
        'kind': 'join',
        'name': 'Julia',
        'data': null,
      })!;
      expect(notice.listId, isNull);
      expect(notice.listName, isNull);
      final without = AppNotice.fromJson({
        'key': 'join:2',
        'kind': 'join',
        'name': 'Julia',
      })!;
      expect(without.listId, isNull);
    });

    test('a trip without a list in data still parses', () {
      final notice = AppNotice.fromJson({
        'key': 'shopping:r2',
        'kind': 'shopping',
        'name': 'Mama',
        'data': <String, dynamic>{},
      })!;
      expect(notice.kind, NoticeKind.shopping);
      expect(notice.listId, isNull);
      expect(notice.listName, isNull);
    });

    test('an unknown kind is not shown, data or not', () {
      expect(
        AppNotice.fromJson({
          'key': 'x:1',
          'kind': 'from-the-future',
          'name': 'Newer',
          'data': {'list_id': 'l1', 'list_name': 'Supermarkt'},
        }),
        isNull,
      );
    });
  });

  group('NoticesRepository', () {
    test('maps the rows and skips kinds it does not know', () async {
      final api = FakeTasksApi(
        replies: {
          'notices': [
            {
              'key': 'join:1',
              'kind': 'join',
              'at': '2026-10-15T07:00:00+00:00',
              'name': 'Julia',
            },
            {'key': 'signin:2', 'kind': 'signin', 'name': 'iPhone'},
            {
              'key': 'mfa_reset:4',
              'kind': 'mfa_reset',
              'name': 'Mama',
              'profile_id': 'p9',
            },
            {'key': 'x:3', 'kind': 'from-the-future', 'name': 'Newer'},
            {
              'key': 'shopping:5',
              'kind': 'shopping',
              'name': 'Mama',
              'data': {'list_id': 'l1', 'list_name': 'Supermarkt'},
            },
          ],
        },
      );
      final result = await NoticesRepository(api).notices(actor: 'p1');

      final notices = result.unwrap();
      expect(notices.map((n) => (n.kind, n.name)), [
        (NoticeKind.join, 'Julia'),
        (NoticeKind.signIn, 'iPhone'),
        (NoticeKind.mfaReset, 'Mama'),
        (NoticeKind.shopping, 'Mama'),
      ]);
      expect((notices[3].listId, notices[3].listName), ('l1', 'Supermarkt'));
      expect(notices[2].profileId, 'p9');
      expect(notices.first.at.toUtc(), DateTime.utc(2026, 10, 15, 7));
      expect(api.calls.single.name, 'notices');
      expect(api.calls.single.params, {'p_actor': 'p1'});
    });

    test('a server without notices is a failure, not a crash', () async {
      final result = await NoticesRepository(FakeTasksApi())
          .notices(actor: 'p1');
      expect(result, isA<Err<List<AppNotice>>>());
    });

    test('dismiss sends the key and the actor', () async {
      final api = FakeTasksApi(replies: {'notice_dismiss': null});
      final result = await NoticesRepository(api)
          .dismiss(actor: 'p1', key: 'join:1');
      expect(result.isOk, isTrue);
      expect(api.calls.single.name, 'notice_dismiss');
      expect(api.calls.single.params, {'p_actor': 'p1', 'p_key': 'join:1'});
    });
  });

  group('Today notices', () {
    testWidgets('a join and a sign-in notice show, in German', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        notices: FakeNoticesRepository([_signIn, _joined]),
      );

      expect(find.text(_de.todayNoticeJoined('Julia')), findsOneWidget);
      expect(
        find.text(_de.todayNoticeSignIn('Daniels iPhone')),
        findsOneWidget,
      );
      expect(find.text(_de.todayNoticeMembers), findsOneWidget);
      expect(find.text(_de.todayNoticeDevices), findsOneWidget);
    });

    testWidgets(
      'a reset of my second factor and a code for someone else, in German',
      (t) async {
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          notices: FakeNoticesRepository([_mfaResetMine, _codeForAnna]),
        );

        expect(find.text(_de.accountNoticeMfaResetYou('Mama')), findsOneWidget);
        expect(
          find.text(_de.accountNoticePasswordReset('Mama', 'Anna')),
          findsOneWidget,
        );
        expect(find.text(_de.todayNoticeMembers), findsNWidgets(2));
      },
    );

    testWidgets('and in English', (t) async {
      await pumpApp(
        t,
        locale: const Locale('en'),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        notices: FakeNoticesRepository([_joined]),
      );

      expect(find.text('Julia joined'), findsOneWidget);
      expect(find.text(_en.todayNoticeDismiss), findsOneWidget);
    });

    testWidgets('"Gesehen" dismisses for the acting profile and hides it', (
      t,
    ) async {
      final repo = FakeNoticesRepository([_joined]);
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        notices: repo,
      );

      await t.tap(find.text(_de.todayNoticeDismiss));
      await t.pumpAndSettle();

      expect(repo.dismissed.single, (actor: guardianId, key: 'join:7'));
      expect(find.text(_de.todayNoticeJoined('Julia')), findsNothing);
    });

    testWidgets('a shopping trip names the shopper and the list', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
        ),
        notices: FakeNoticesRepository([_shopping]),
      );

      expect(
        find.text(_de.todayNoticeShopping('Mama', 'Baumarkt')),
        findsOneWidget,
      );
      expect(find.text(_de.todayNoticeShoppingList), findsOneWidget);
      expect(find.text(_de.todayNoticeDismiss), findsOneWidget);
    });

    testWidgets('"Zur Liste" opens that list on the Shopping tab', (t) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
        ),
        notices: FakeNoticesRepository([_shopping]),
      );
      final router = container.read(routerProvider);
      final before = router.routerDelegate.currentConfiguration.uri.toString();
      expect(container.read(homeTabProvider), HomeTab.today);

      await t.tap(find.text(_de.todayNoticeShoppingList));
      await t.pumpAndSettle();

      expect(container.read(homeTabProvider), HomeTab.shopping);
      expect(container.read(selectedListIdProvider), 'l-garden');
      // No page on top of the home shell: the settings are not opened.
      expect(router.routerDelegate.currentConfiguration.uri.toString(), before);
      expect(find.text(_de.todayNoticeShoppingList), findsNothing);
    });

    testWidgets('"Gesehen" dismisses a shopping trip like any notice', (
      t,
    ) async {
      final repo = FakeNoticesRepository([_shopping]);
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
        ),
        notices: repo,
      );

      await t.tap(find.text(_de.todayNoticeDismiss));
      await t.pumpAndSettle();

      expect(repo.dismissed.single, (actor: guardianId, key: 'shopping:run-1'));
      expect(
        find.text(_de.todayNoticeShopping('Mama', 'Baumarkt')),
        findsNothing,
      );
    });

    testWidgets('no notices, no cards', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );

      expect(find.text(_de.todayNoticeDismiss), findsNothing);
    });
  });
}
