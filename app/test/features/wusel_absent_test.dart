import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/calendar/application/feed_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/pin_pad.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';
import 'package:wuselwall/features/shortcuts/application/shortcut_providers.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

final de = lookupAppLocalizations(const Locale('de'));

/// The household has no school yet, so the timetable import shows its empty state.
const _noSchool = SchoolData(
  schools: [],
  periods: [],
  terms: [],
  subjects: [],
  timetables: [],
  lessons: [],
  exceptions: [],
  holidays: [],
);

Future<void> _open(WidgetTester t, String route, {Object? extra}) async {
  final container = await pumpApp(
    t,
    overrides: [
      ...baseOverrides(identity: FakeIdentityRepository(current: device())),
      feedTokensProvider.overrideWith((ref) async => const []),
      shortcutTokensProvider.overrideWith((ref) async => const []),
    ],
    school: FakeSchoolRepository(data: _noSchool),
  );
  container.read(routerProvider).go(route, extra: extra);
  await t.pumpAndSettle();
}

/// specs/25 "Where Wusel never appears": settings (but the outfit picker and Wusel's
/// own setting), the PIN pad, errors and capture flows. Their empty states leave the
/// app's peeking Wusel out.
void main() {
  testWidgets('an ordinary empty state does show Wusel', (t) async {
    // The control: without it the tests below would pass for the wrong reason.
    await _open(t, Routes.recipes);
    expect(find.byType(Wusel), findsOneWidget);
  });

  for (final (route, text, extra) in [
    (Routes.shortcuts, de.shortcutEmpty, null),
    (Routes.feedTokens, de.feedEmpty, null),
    (Routes.externalCalendars, de.extCalEmpty, null),
    (
      Routes.timetableImport,
      de.schoolSetupCardBody,
      const TimetableImportArgs(import: TimetableImport(lessons: [])),
    ),
  ]) {
    testWidgets('$route shows its empty state without Wusel', (t) async {
      await _open(t, route, extra: extra);
      expect(find.textContaining(text), findsOneWidget);
      expect(find.byType(Wusel), findsNothing);
    });
  }

  testWidgets('the PIN pad shows no Wusel', (t) async {
    await _open(t, Routes.recipes);
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(Scaffold).last),
        builder: (_) => const PinPadDialog(
          guardian: Member(
            id: guardianId,
            displayName: 'Sabine',
            color: Color(0xFF2D6A4F),
            role: Role.guardian,
            active: true,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(PinPadDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PinPadDialog),
        matching: find.byType(Wusel),
      ),
      findsNothing,
    );
  });
}
