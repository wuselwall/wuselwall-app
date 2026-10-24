import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/today/ui/today_page.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

/// The Herbstferien of the reference household, from Saturday to the next Sunday.
final _autumn = HolidayRecord(
  id: 'autumn',
  name: 'Herbstferien',
  startsOn: DateTime(2026, 10, 10),
  endsOn: DateTime(2026, 10, 25),
);

Future<ProviderContainer> _today(WidgetTester t, DateTime now) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      now: now,
    ),
    school: FakeSchoolRepository(
      data: referenceSchoolData(holidays: [_autumn]),
    ),
    size: const Size(390, 844),
  );
  // The adult home opens on the calendar.
  await t.tap(find.text('Heute').last);
  await t.pumpAndSettle();
  return container;
}

final _ferienWusel = find.byKey(const ValueKey('today-ferien-wusel'));

/// specs/25 "Where Wusel appears" (adult, a special day) and specs/26 "Seasons and
/// occasions" (the Ferien ribbon).
void main() {
  testWidgets('the first day of the Ferien: the ribbon, and Wusel waves once', (
    t,
  ) async {
    await _today(t, DateTime(2026, 10, 10, 9));
    expect(find.text('Ferien!'), findsOneWidget);
    expect(_ferienWusel, findsOneWidget);
    expect(
      find.descendant(of: _ferienWusel, matching: find.byType(Wusel)),
      findsOneWidget,
    );
    // One Wusel per screen: an empty Today leaves its own picture out.
    expect(find.byType(Wusel), findsOneWidget);
  });

  testWidgets('the last day has its ribbon and no Wusel of its own', (t) async {
    await _today(t, DateTime(2026, 10, 25, 9));
    expect(find.text('Morgen ist wieder Schule'), findsOneWidget);
    expect(_ferienWusel, findsNothing);
  });

  testWidgets('an ordinary day has neither', (t) async {
    await _today(t, DateTime(2026, 10, 14, 9));
    expect(find.text('Ferien!'), findsNothing);
    expect(_ferienWusel, findsNothing);
  });

  test('a birthday on the same day keeps the screen\'s one Wusel', () {
    final container = ProviderContainer(
      overrides: [
        ambienceProvider.overrideWith(
          (ref) => const Ambience(
            phase: SkyPhase.day,
            ferien: FerienEdge.first,
            birthdays: [Color(0xFF2D6A4F)],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(ferienWuselTodayProvider), isFalse);
  });

  test('a household that switched the Ferien off gets no Ferien Wusel', () {
    final container = ProviderContainer(
      overrides: [
        // The switch empties the ambience's Ferien (see ambienceFor).
        ambienceProvider.overrideWith(
          (ref) => const Ambience(phase: SkyPhase.day),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(ferienWuselTodayProvider), isFalse);
  });
}
