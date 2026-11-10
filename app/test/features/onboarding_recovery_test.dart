import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/household/data/new_family_draft_store.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/ui/account_sections.dart';

import '../support/fakes.dart';

class _Identity extends FakeIdentityRepository {
  _Identity(List<Member> members) : super(current: device(), members: members);

  int enrolments = 0;

  @override
  Future<Result<TotpEnrolment>> totpEnrol() async {
    enrolments++;
    return const Ok(
      TotpEnrolment(
        factorId: 'factor-1',
        uri: 'otpauth://totp/Example?secret=TEST',
        secret: 'TEST',
      ),
    );
  }
}

const _account = Account(
  userId: 'user-1',
  hasHousehold: false,
  creation: HouseholdCreation.open,
  givenName: 'Alex',
  fullName: 'Alex Example',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'drafts survive a new store and are isolated by server and account',
    () async {
      final store = NewFamilyDraftStore();
      const first = NewFamilyDraft(
        familyName: 'One',
        displayName: 'Alex',
        swatch: 1,
        seedExamples: true,
      );
      const latest = NewFamilyDraft(
        familyName: 'Two',
        displayName: '',
        swatch: 3,
        seedExamples: false,
      );
      unawaited(store.save('https://example.org', 'a', first));
      await store.save('https://example.org', 'a', latest);
      final restarted = NewFamilyDraftStore();
      expect(
        (await restarted.read('https://example.org', 'a'))?.familyName,
        'Two',
      );
      expect(await restarted.read('https://other.example.org', 'a'), isNull);
      expect(await restarted.read('https://example.org', 'b'), isNull);
      unawaited(store.save('https://example.org', 'a', first));
      await store.clear('https://example.org', 'a');
      expect(await restarted.read('https://example.org', 'a'), isNull);
    },
  );

  for (final language in ['de', 'en', 'fr', 'es']) {
    testWidgets('H1 resumes edited fields, colour and examples in $language', (
      t,
    ) async {
      final l10n = lookupAppLocalizations(Locale(language));
      Future<ProviderContainer> open() => pumpApp(
        t,
        locale: Locale(language),
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: FakeHouseholdOnboardingRepository(accountValue: _account),
          draftStore: NewFamilyDraftStore(),
        ),
      );
      var container = await open();
      await t.enterText(
        find.widgetWithText(TextFormField, l10n.householdNewFamilyName),
        'Our family',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, l10n.householdNewYourName),
        'Sam',
      );
      await t.tap(find.bySemanticsLabel(l10n.householdNewColourOption('4')));
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      // A fresh widget tree, provider container and secure-store instance: no in-memory draft.
      await unmountApp(t, container);
      container = await open();
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, l10n.householdNewFamilyName),
            )
            .controller!
            .text,
        'Our family',
      );
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, l10n.householdNewYourName),
            )
            .controller!
            .text,
        'Sam',
      );
      expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      final colour = t.widget<Semantics>(
        find.bySemanticsLabel(l10n.householdNewColourOption('4')).first,
      );
      expect(colour.properties.selected, isTrue);
      final draft = await NewFamilyDraftStore().read(
        'http://localhost',
        'user-1',
      );
      expect(draft?.swatch, 3);
      expect(draft?.seedExamples, isFalse);
      await unmountApp(t, container);
    });

    testWidgets(
      'single-guardian warning precedes TOTP enrolment at large $language text',
      (t) async {
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final l10n = lookupAppLocalizations(Locale(language));
        final identity = _Identity([
          testMembers.firstWhere((m) => m.id == guardianId),
          const Member(
            id: 'unclaimed',
            displayName: 'Second parent',
            color: Color(0xFF336699),
            role: Role.guardian,
            active: true,
            hasAccount: false,
          ),
          const Member(
            id: 'inactive',
            displayName: 'Former parent',
            color: Color(0xFF336699),
            role: Role.guardian,
            active: false,
          ),
        ]);
        final container = await pumpApp(
          t,
          locale: Locale(language),
          size: const Size(390, 844),
          overrides: baseOverrides(identity: identity),
        );
        container.read(routerProvider).go(Routes.settingsAccount);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text(l10n.totpEnable).hitTestable(),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pumpAndSettle();
        await t.tap(find.text(l10n.totpEnable));
        await t.pumpAndSettle();
        expect(find.text(l10n.totpSingleGuardianWarning), findsOneWidget);
        expect(identity.enrolments, 0);
        await t.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.cancel),
          ),
        );
        await t.pumpAndSettle();
        expect(identity.enrolments, 0);
        await t.tap(find.text(l10n.totpEnable));
        await t.pumpAndSettle();
        await t.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.totpEnable),
          ),
        );
        await t.pumpAndSettle();
        expect(identity.enrolments, 1);
        expect(find.text(l10n.totpScanBody), findsOneWidget);
        expect(t.takeException(), isNull);
        await unmountApp(t, container);
      },
    );
  }

  testWidgets('creation clears the draft and never stores the founder code', (
    t,
  ) async {
    final identity = FakeIdentityRepository();
    final household = FakeHouseholdOnboardingRepository(identity: identity);
    final store = NewFamilyDraftStore();
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: identity,
        household: household,
        draftStore: store,
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('de'));
    await t.enterText(
      find.widgetWithText(TextFormField, l10n.householdNewFamilyName),
      'Family',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, l10n.householdNewFounderCode),
      'secret-founder-code',
    );
    final saved = await store.read('http://localhost', 'user-1');
    expect(saved?.familyName, 'Family');
    // There are only the four non-secret choices in the storage payload.
    final values = await const FlutterSecureStorage().readAll();
    expect(values.values.join(), isNot(contains('secret-founder-code')));
    await t.ensureVisible(find.byKey(const ValueKey('new-family-create')));
    await t.tap(find.byKey(const ValueKey('new-family-create')));
    await t.pumpAndSettle();
    expect(household.created, hasLength(1));
    expect(await store.read('http://localhost', 'user-1'), isNull);
    await unmountApp(t, container);
  });

  for (final invitation in [false, true]) {
    testWidgets('leaving H1 clears the draft (invitation: $invitation)', (
      t,
    ) async {
      final store = NewFamilyDraftStore();
      final identity = FakeIdentityRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          household: FakeHouseholdOnboardingRepository(accountValue: _account),
          draftStore: store,
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('de'));
      await t.enterText(
        find.widgetWithText(TextFormField, l10n.householdNewFamilyName),
        'Private draft',
      );
      expect(await store.read('http://localhost', 'user-1'), isNotNull);
      final exit = find.text(
        invitation ? l10n.householdNewInvited : l10n.householdNewSignOut,
      );
      await t.ensureVisible(exit);
      await t.tap(exit);
      await t.pumpAndSettle();
      expect(await store.read('http://localhost', 'user-1'), isNull);
      if (!invitation) expect(identity.signedOut, isTrue);
      await unmountApp(t, container);
    });
  }

  testWidgets('a failed create keeps the local draft for retry', (t) async {
    final store = NewFamilyDraftStore();
    final household = FakeHouseholdOnboardingRepository(
      accountValue: _account,
      createResult: const Err(NetworkFailure()),
    );
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        household: household,
        draftStore: store,
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('de'));
    await t.enterText(
      find.widgetWithText(TextFormField, l10n.householdNewFamilyName),
      'Retry family',
    );
    await t.tap(find.byKey(const ValueKey('new-family-create')));
    await t.pumpAndSettle();
    expect(household.created, hasLength(1));
    expect(
      (await store.read('http://localhost', 'user-1'))?.familyName,
      'Retry family',
    );
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('new-family-create')))
          .onPressed,
      isNotNull,
    );
    await unmountApp(t, container);
  });

  testWidgets(
    'a second active guardian account needs no warning; passkeys default off',
    (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final identity = _Identity([
        testMembers.firstWhere((m) => m.id == guardianId),
        const Member(
          id: 'second',
          displayName: 'Second parent',
          color: Color(0xFF336699),
          role: Role.guardian,
          active: true,
        ),
      ]);
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity),
      );
      container.read(routerProvider).go(Routes.settingsAccount);
      await t.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('de'));
      await t.ensureVisible(find.text(l10n.totpEnable));
      await t.tap(find.text(l10n.totpEnable));
      await t.pumpAndSettle();
      expect(identity.enrolments, 1);
      expect(find.text(l10n.totpSingleGuardianWarning), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SecuritySection),
          matching: find.byIcon(Icons.fingerprint),
        ),
        findsNothing,
      );
      expect(
        const AppConfig(
          environment: 'test',
          supabaseUrl: 'https://example.org',
          supabasePublishableKey: 'public',
        ).passkeys,
        isFalse,
      );
      await unmountApp(t, container);
    },
  );
}
