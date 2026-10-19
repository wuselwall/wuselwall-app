import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/result.dart';
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

void main() {
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
            {'key': 'x:3', 'kind': 'from-the-future', 'name': 'Newer'},
          ],
        },
      );
      final result = await NoticesRepository(api).notices(actor: 'p1');

      final notices = result.unwrap();
      expect(notices.map((n) => (n.kind, n.name)), [
        (NoticeKind.join, 'Julia'),
        (NoticeKind.signIn, 'iPhone'),
      ]);
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
