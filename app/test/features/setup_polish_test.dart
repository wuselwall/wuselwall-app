import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/household/ui/new_family_page.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/setup/ui/server_choice_page.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// A create that waits until the test lets it finish.
class _SlowHousehold extends FakeHouseholdOnboardingRepository {
  final release = Completer<void>();

  @override
  Future<Result<void>> create({
    required String householdName,
    required String displayName,
    required String colorHex,
    required String timezone,
    required String locale,
    required String? founderCode,
    required bool seedExamples,
    required String deviceLabel,
  }) async {
    await release.future;
    return super.create(
      householdName: householdName,
      displayName: displayName,
      colorHex: colorHex,
      timezone: timezone,
      locale: locale,
      founderCode: founderCode,
      seedExamples: seedExamples,
      deviceLabel: deviceLabel,
    );
  }
}

/// Round 3 UI findings J-1 to J-9: setup and onboarding.
void main() {
  // The app's own fonts, so the narrow layouts measure as on a phone.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('AtkinsonHyperlegibleNext');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$weight.ttf'),
      );
    }
    await loader.load();
  });

  ButtonStyleButton buttonOf(WidgetTester t, Finder label) =>
      t.widget<ButtonStyleButton>(
        find.ancestor(
          of: label,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

  testWidgets('J-8: the front door has one filled action and equal rows', (
    t,
  ) async {
    await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
      ),
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      t.widget(find.byKey(const ValueKey('door-email'))),
      isA<FilledButton>(),
    );
    for (final key in ['door-pair', 'door-invite']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
    }
    // The rows sit at the same indent with their icons.
    expect(
      t.getTopLeft(find.text(_de.pairFrontDoorAction)).dx,
      t.getTopLeft(find.text(_de.inviteDoorAction)).dx,
    );
  });

  testWidgets('J-1: with a password, Anmelden is the one filled button', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
      ),
    );
    container.read(routerProvider).go(Routes.signIn);
    await t.pumpAndSettle();
    expect(find.text(_de.emailContinue), findsOneWidget);

    await t.tap(find.text(_de.emailHavePassword));
    await t.pumpAndSettle();

    // No "Weiter" that would send a code instead.
    expect(find.text(_de.emailContinue), findsNothing);
    expect(buttonOf(t, find.text(_de.signInAction)), isA<FilledButton>());
    expect(find.byType(FilledButton), findsOneWidget);
    expect(buttonOf(t, find.text(_de.emailUseCodeInstead)), isA<TextButton>());
  });

  testWidgets('J-7: an empty invitation is asked for on the field', (t) async {
    final container = await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
      ),
    );
    container.read(routerProvider).go(Routes.inviteCode);
    await t.pumpAndSettle();
    await t.tap(find.text(_de.inviteCheckAction));
    await t.pumpAndSettle();

    final field = find.byKey(const ValueKey('invite-code-field'));
    expect(
      t.widget<TextField>(field).decoration!.errorText,
      _de.inviteCodeEmpty,
    );
    expect(find.text(_de.inviteCodeInvalidFormat), findsNothing);

    await t.enterText(field, 'nonsense!');
    await t.tap(find.text(_de.inviteCheckAction));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(field).decoration!.errorText,
      _de.inviteCodeInvalidFormat,
    );
  });

  testWidgets('J-9: an empty server address asks for the address', (t) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(UiRegister.adult, Shade.light),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          locale: const Locale('de'),
          home: ServerChoicePage(
            onAddress: (_) async => null,
            onDemo: () {},
            canScan: false,
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('server-connect')));
    await t.pumpAndSettle();
    expect(find.text(_de.serverEmpty), findsOneWidget);
    expect(find.text(_de.serverInvalid), findsNothing);
    // The invitation format is said at the field, not in the lead.
    expect(find.text(_de.serverAddressHelper), findsNothing);
  });

  testWidgets('J-9: the demo hint keeps its last two words together', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(UiRegister.adult, Shade.light),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          locale: const Locale('de'),
          home: ServerChoicePage(
            onAddress: (_) async => null,
            onDemo: () {},
            canScan: false,
          ),
        ),
      ),
    );
    // "dieses Gerät." never splits, so "Gerät." is never alone on a line.
    expect(find.textContaining('dieses\u00A0Gerät.'), findsOneWidget);
  });

  group('J-5, J-6, J-9: Neue Familie', () {
    Future<_SlowHousehold> openNewFamily(WidgetTester t, double width) async {
      final household = _SlowHousehold();
      await pumpApp(
        t,
        size: Size(width, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: household,
        ),
      );
      return household;
    }

    testWidgets('the setup-code helper is whole at 360 px', (t) async {
      final household = await openNewFamily(t, 360);
      final helper = find.text(_de.householdNewFounderHelp);
      expect(helper, findsOneWidget);
      expect(
        (helper.evaluate().single.renderObject! as RenderParagraph)
            .didExceedMaxLines,
        isFalse,
      );
      household.release.complete();
    });

    testWidgets('the swatches sit 4 × 2 on a phone, in one row on a tablet', (
      t,
    ) async {
      final household = await openNewFamily(t, 390);
      final swatches = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').startsWith(
              _de.householdNewColourOption('').trim(),
            ),
      );
      final count = MemberPalette.swatches.length;
      expect(swatches, findsNWidgets(count));
      final tops = [
        for (var i = 0; i < count; i++) t.getTopLeft(swatches.at(i)).dy,
      ];
      expect(tops.toSet(), hasLength(2));
      expect(tops.where((y) => y == tops.first), hasLength(count ~/ 2));
      // No unlabelled colour dot in the bar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircleAvatar),
        ),
        findsNothing,
      );

      t.view.physicalSize = const Size(1024, 768);
      await t.pumpAndSettle();
      expect({
        for (var i = 0; i < count; i++) t.getTopLeft(swatches.at(i)).dy,
      }, hasLength(1));
      household.release.complete();
    });

    testWidgets('the time zone reads as a city', (t) async {
      final household = await openNewFamily(t, 390);
      expect(find.textContaining('Europe/'), findsNothing);
      expect(find.textContaining('Berlin'), findsOneWidget);
      household.release.complete();
    });

    testWidgets('"Familie anlegen" shows that it is working', (t) async {
      final household = await openNewFamily(t, 390);
      await t.enterText(
        find.widgetWithText(TextFormField, _de.householdNewFounderCode),
        'ABCD2345',
      );
      await t.tap(find.text(_de.householdNewCreate));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(_de.householdNewCreating), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      household.release.complete();
      await t.pumpAndSettle();
      expect(find.text(_de.householdNewCreating), findsNothing);
    });
  });

  test('time zones read as their city', () {
    expect(timezoneCity('Europe/Berlin'), 'Berlin');
    expect(timezoneCity('America/Argentina/Buenos_Aires'), 'Buenos Aires');
    expect(timezoneCity('UTC'), 'UTC');
  });

  testWidgets('J-2, J-3, J-9: the first school has one save and says why', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      size: const Size(390, 844),
      school: FakeSchoolRepository(
        data: const SchoolData(
          schools: [],
          periods: [],
          terms: [],
          subjects: [],
          timetables: [],
          lessons: [],
          exceptions: [],
          holidays: [],
        ),
      ),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    container.read(routerProvider).go(Routes.schoolSetup);
    await t.pumpAndSettle();

    expect(find.text(_de.schoolsUiAddSchool), findsNothing);
    final name = find.byKey(const ValueKey('school-name'));
    expect(t.widget<TextField>(name).decoration!.helperText, _de.fieldRequired);
    expect(buttonOf(t, find.text(_de.schoolSetupCreate)).onPressed, isNull);

    await t.enterText(name, 'Schule am See');
    await t.pumpAndSettle();
    expect(t.widget<TextField>(name).decoration!.helperText, isNull);
    // One save while creating: the bar's "Speichern" stays away.
    expect(find.text(_de.save), findsNothing);
    expect(buttonOf(t, find.text(_de.schoolSetupCreate)).onPressed, isNotNull);
  });
}
