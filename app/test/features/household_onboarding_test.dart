import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/household/application/household_providers.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

import '../support/fakes.dart';

/// Every test pretends to be an iPhone, so the device label is deterministic.
void _asIphone() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

void main() {
  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets(
    'a signed-in account without a household starts H1, not the front door',
    (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: FakeHouseholdOnboardingRepository(),
        ),
      );
      expect(find.text('Neue Familie'), findsOneWidget);
      expect(find.text('Mit Apple fortfahren'), findsNothing);
      expect(find.text('Dein Name'), findsOneWidget);
    },
  );

  testWidgets('the founder code is asked only in code mode', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        household: FakeHouseholdOnboardingRepository(),
      ),
    );
    expect(field('Gründungscode'), findsOneWidget);
  });

  testWidgets('in open mode H1 has no founder code field', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        household: FakeHouseholdOnboardingRepository(
          accountValue: const Account(
            userId: 'user-1',
            hasHousehold: false,
            creation: HouseholdCreation.open,
          ),
        ),
      ),
    );
    expect(find.text('Neue Familie'), findsOneWidget);
    expect(field('Gründungscode'), findsNothing);
  });

  testWidgets(
    'the family name and the given name are prefilled from the account',
    (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: FakeHouseholdOnboardingRepository(),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == 'Familie Huser',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == 'Daniel',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'creating sends the chosen values, then H2 shows once before Today',
    (t) async {
      _asIphone();
      final identity = FakeIdentityRepository();
      final household = FakeHouseholdOnboardingRepository(identity: identity);
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, household: household),
      );

      await t.enterText(field('Gründungscode'), 'ABCD2345');
      await t.tap(find.text('Familie anlegen'));
      await t.pumpAndSettle();

      expect(household.created, hasLength(1));
      final sent = household.created.single;
      expect(sent.householdName, 'Familie Huser');
      expect(sent.displayName, 'Daniel');
      expect(sent.colorHex, '#7B3FE4');
      expect(sent.timezone, 'Europe/Berlin');
      expect(sent.locale, 'de-DE');
      expect(sent.founderCode, 'ABCD2345');
      expect(sent.seedExamples, isTrue);
      expect(sent.deviceLabel, 'Daniels iPhone');

      // The session refresh of the app: the device exists now, so the session is Ready.
      container.invalidate(sessionStateProvider);
      await t.pumpAndSettle();
      expect(find.text('Wer gehört noch zu euch?'), findsOneWidget);
      expect(find.text('Neue Familie'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a wrong founder code is shown on the field and stays on H1', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        household: FakeHouseholdOnboardingRepository(
          createResult: const Err(
            ValidationFailure(code: 'founder_code_invalid'),
          ),
        ),
      ),
    );
    await t.enterText(field('Gründungscode'), 'nope');
    await t.tap(find.text('Familie anlegen'));
    await t.pumpAndSettle();
    expect(find.text('Der Gründungscode stimmt nicht.'), findsOneWidget);
    expect(find.text('Neue Familie'), findsOneWidget);
  });

  testWidgets('a rate-limited creation explains the wait', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        household: FakeHouseholdOnboardingRepository(
          createResult: const Err(PermissionFailure(code: 'rate_limited')),
        ),
      ),
    );
    await t.enterText(field('Gründungscode'), 'nope');
    await t.tap(find.text('Familie anlegen'));
    await t.pumpAndSettle();
    expect(find.textContaining('Zu viele Versuche'), findsOneWidget);
  });

  testWidgets(
    'a missing code is refused by the server and explained on the field',
    (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: FakeHouseholdOnboardingRepository(
            createResult: const Err(
              ValidationFailure(code: 'founder_code_required'),
            ),
          ),
        ),
      );
      await t.enterText(field('Gründungscode'), 'x');
      await t.tap(find.text('Familie anlegen'));
      await t.pumpAndSettle();
      expect(
        find.text('Neue Familien gibt es gerade nur mit Gründungscode.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the invitation link keeps the person on H1 with a note', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        household: FakeHouseholdOnboardingRepository(),
      ),
    );
    await t.tap(find.text('Ich wurde eingeladen'));
    await t.pumpAndSettle();
    expect(
      find.text('Einladungen kommen mit dem nächsten Update.'),
      findsOneWidget,
    );
    expect(find.text('Neue Familie'), findsOneWidget);
  });

  group('H2', () {
    /// Creates the household and lands on H2.
    Future<
      ({
        FakeHouseholdOnboardingRepository household,
        ProviderContainer container,
      })
    >
    onH2(WidgetTester t, {bool examples = true}) async {
      final identity = FakeIdentityRepository();
      final household = FakeHouseholdOnboardingRepository(identity: identity);
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, household: household),
      );
      await t.enterText(field('Gründungscode'), 'ABCD2345');
      if (!examples) {
        await t.tap(
          find.text('Mit Beispielen starten — 5 Aufgaben, 3 Belohnungen'),
        );
        await t.pump();
      }
      await t.tap(find.text('Familie anlegen'));
      await t.pumpAndSettle();
      container.invalidate(sessionStateProvider);
      await t.pumpAndSettle();
      expect(find.text('Wer gehört noch zu euch?'), findsOneWidget);
      return (household: household, container: container);
    }

    testWidgets('add and remove rows, and the kind of each person', (t) async {
      await onH2(t);
      expect(find.text('Papa (du)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);

      await t.tap(find.text('Person hinzufügen'));
      await t.pump();
      expect(find.widgetWithText(TextField, 'Name'), findsNWidgets(2));

      await t.enterText(find.widgetWithText(TextField, 'Name').at(0), 'Lotta');
      await t.enterText(find.widgetWithText(TextField, 'Name').at(1), 'Sabine');
      // The second row becomes an adult.
      await t.tap(find.text('Erwachsen').at(1));
      await t.pump();

      await t.tap(find.byTooltip('Entfernen').first);
      await t.pump();
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
    });

    testWidgets('Fertig adds the people named, with their kind', (t) async {
      final h = await onH2(t);
      await t.tap(find.text('Person hinzufügen'));
      await t.pump();
      await t.enterText(find.widgetWithText(TextField, 'Name').at(0), 'Lotta');
      await t.enterText(find.widgetWithText(TextField, 'Name').at(1), 'Sabine');
      await t.tap(find.text('Erwachsen').at(1));
      await t.pump();

      await t.tap(find.text('Fertig'));
      await t.pumpAndSettle();

      expect(h.household.addedMembers, hasLength(1));
      final added = h.household.addedMembers.single;
      expect(added.map((m) => (m.displayName, m.isChild)).toList(), [
        ('Lotta', true),
        ('Sabine', false),
      ]);
      // With children and examples on, the child chores follow.
      expect(h.household.examplesCompleted, 1);
      expect(find.text('Neue Familie'), findsNothing);
      expect(find.text('Wer gehört noch zu euch?'), findsNothing);
    });

    testWidgets('without children the examples are not completed again', (
      t,
    ) async {
      final h = await onH2(t);
      await t.tap(find.text('Erwachsen').at(0));
      await t.pump();
      await t.enterText(find.widgetWithText(TextField, 'Name').at(0), 'Sabine');
      await t.tap(find.text('Fertig'));
      await t.pumpAndSettle();
      expect(h.household.addedMembers.single.single.isChild, isFalse);
      expect(h.household.examplesCompleted, 0);
    });

    testWidgets('Überspringen adds nobody and goes on', (t) async {
      final h = await onH2(t);
      await t.tap(find.text('Überspringen'));
      await t.pumpAndSettle();
      expect(h.household.addedMembers, isEmpty);
      expect(h.container.read(onboardingPlanProvider), isNull);
    });
  });
}
