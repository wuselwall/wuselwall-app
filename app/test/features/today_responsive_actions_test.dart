import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

import '../support/fake_getting_started.dart';
import '../support/fake_notices.dart';
import '../support/fakes.dart';

const _locales = [Locale('de'), Locale('en'), Locale('fr'), Locale('es')];
const _widths = [390.0, 411.0];

void main() {
  for (final locale in _locales) {
    final l10n = lookupAppLocalizations(locale);
    for (final width in _widths) {
      testWidgets(
        'getting-started action follows its title at ${width.toInt()}dp, '
        'text scale 1.5 (${locale.languageCode})',
        (t) async {
          t.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpApp(
            t,
            locale: locale,
            size: Size(width, 844),
            overrides: baseOverrides(
              identity: FakeIdentityRepository(current: device()),
            ),
            gettingStarted: FakeGettingStartedRepository(const [
              GettingStartedItem(item: StartItem.school, done: false),
            ]),
          );

          final title = find.text(l10n.todayStartSchool);
          final action = find.text(l10n.todayStartNotNeeded);
          expect(title, findsOneWidget);
          expect(action, findsOneWidget);
          expect(t.getSize(title).width, greaterThan(200));
          expect(
            t.getRect(action).top,
            greaterThanOrEqualTo(t.getRect(title).bottom - 1),
          );
          expect(find.byType(TextButton), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );

      testWidgets('notice actions follow the message at ${width.toInt()}dp, '
          'text scale 1.5 (${locale.languageCode})', (t) async {
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(
          t,
          locale: locale,
          size: Size(width, 844),
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          notices: FakeNoticesRepository([
            AppNotice(
              key: 'join:large-text',
              kind: NoticeKind.join,
              name: 'Alexandra',
              at: DateTime(2026, 10, 24, 9),
            ),
          ]),
        );

        final message = find.text(l10n.todayNoticeJoined('Alexandra'));
        final settingsAction = find.text(l10n.todayNoticeMembers);
        final dismissAction = find.text(l10n.todayNoticeDismiss);
        expect(message, findsOneWidget);
        expect(settingsAction, findsOneWidget);
        expect(dismissAction, findsOneWidget);
        expect(t.getSize(message).width, greaterThan(200));
        expect(
          t.getRect(settingsAction).top,
          greaterThanOrEqualTo(t.getRect(message).bottom - 1),
        );
        expect(
          t.getRect(dismissAction).top,
          greaterThanOrEqualTo(t.getRect(message).bottom - 1),
        );
        expect(find.byType(TextButton), findsNWidgets(2));
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('wide getting-started row stays compact at large text', (
    t,
  ) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(
      t,
      locale: const Locale('de'),
      size: const Size(1000, 900),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      gettingStarted: FakeGettingStartedRepository(const [
        GettingStartedItem(item: StartItem.school, done: false),
      ]),
    );

    final title = find.text(l10n.todayStartSchool);
    final action = find.text(l10n.todayStartNotNeeded);
    expect(action, findsOneWidget);
    expect(
      t.getRect(action).left,
      greaterThanOrEqualTo(t.getRect(title).right - 1),
    );
  });

  testWidgets('wide notice row stays compact at large text', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(
      t,
      locale: const Locale('de'),
      size: const Size(1000, 900),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      notices: FakeNoticesRepository([
        AppNotice(
          key: 'join:wide-text',
          kind: NoticeKind.join,
          name: 'Alexandra',
          at: DateTime(2026, 10, 24, 9),
        ),
      ]),
    );

    final message = find.text(l10n.todayNoticeJoined('Alexandra'));
    final action = find.text(l10n.todayNoticeMembers);
    expect(action, findsOneWidget);
    expect(
      t.getRect(action).left,
      greaterThanOrEqualTo(t.getRect(message).right - 1),
    );
  });

  testWidgets('getting-started dismissal still works in the reflowed row', (
    t,
  ) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeGettingStartedRepository(const [
      GettingStartedItem(item: StartItem.school, done: false),
    ]);
    await pumpApp(
      t,
      size: const Size(411, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      gettingStarted: repository,
    );

    await t.tap(
      find.text(lookupAppLocalizations(const Locale('de')).todayStartNotNeeded),
    );
    await t.pumpAndSettle();

    expect(repository.dismissed.single, (
      actor: guardianId,
      item: StartItem.school,
    ));
  });

  testWidgets('notice dismissal still works in the reflowed card', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeNoticesRepository([
      AppNotice(
        key: 'join:large-text',
        kind: NoticeKind.join,
        name: 'Alexandra',
        at: DateTime(2026, 10, 24, 9),
      ),
    ]);
    await pumpApp(
      t,
      size: const Size(411, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      notices: repository,
    );

    await t.tap(
      find.text(lookupAppLocalizations(const Locale('de')).todayNoticeDismiss),
    );
    await t.pumpAndSettle();

    expect(repository.dismissed.single, (
      actor: guardianId,
      key: 'join:large-text',
    ));
  });
}
