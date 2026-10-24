import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/ui/week_review_widgets.dart';

void main() {
  DateTime? at(DateTime now) =>
      weekReviewWeek(now, weekday: DateTime.sunday, hour: 16, minute: 0);

  test(
    'the look-back opens on Sunday at 16:00 and stays until Monday 10:00',
    () {
      // 25 October 2026 is a Sunday; its week began on Monday the 19th.
      expect(at(DateTime(2026, 10, 25, 15, 59)), isNull);
      expect(at(DateTime(2026, 10, 25, 16)), DateTime(2026, 10, 19));
      expect(at(DateTime(2026, 10, 26, 9, 59)), DateTime(2026, 10, 19));
      expect(at(DateTime(2026, 10, 26, 10)), isNull);
      expect(at(DateTime(2026, 10, 22, 18)), isNull);
    },
  );

  test('a look-back on a Monday morning is about the week just ended', () {
    // 26 October 2026 is a Monday.
    expect(
      weekReviewWeek(
        DateTime(2026, 10, 26, 9),
        weekday: DateTime.monday,
        hour: 8,
        minute: 0,
      ),
      DateTime(2026, 10, 19),
    );
  });

  test('an unknown kind reads as the always-true line', () {
    final h = WeekHighlight.fromJson({
      'profile_id': 'p',
      'highlight': {'kind': 'streak', 'title': 'Zähne putzen'},
    });
    expect(h.kind, HighlightKind.streak);
    final unknown = WeekHighlight.fromJson({
      'profile_id': 'p',
      'highlight': {'kind': 'something_new'},
    });
    // A kind this app does not know reads as the always-true line.
    expect(unknown.kind, HighlightKind.here);
  });

  // P10: nobody's line is a number another line could be compared with. The server
  // sends no number (pgTAP 235 and 237); the app's sentences add none either.
  for (final lang in AppLocalizations.supportedLocales) {
    test('no member line has a number in it (${lang.languageCode})', () {
      final l10n = lookupAppLocalizations(lang);
      for (final kind in HighlightKind.values) {
        final line = highlightLine(
          l10n,
          WeekHighlight(profileId: 'p', kind: kind, title: 'Pfannkuchen'),
        );
        expect(line, isNotEmpty);
        expect(
          RegExp(r'[0-9]').hasMatch(line),
          isFalse,
          reason: '$kind: "$line"',
        );
      }
    });
  }

  test('a clock change does not move the look-back', () {
    // 25 October 2026 and 29 March 2026: the clocks change in much of Europe. Calendar
    // days, not 24-hour spans, so the window is the same whatever the device's zone.
    expect(at(DateTime(2026, 10, 25, 16)), DateTime(2026, 10, 19));
    expect(at(DateTime(2026, 10, 26, 9, 59)), DateTime(2026, 10, 19));
    expect(at(DateTime(2026, 10, 26, 10)), isNull);
    expect(at(DateTime(2026, 3, 29, 16, 30)), DateTime(2026, 3, 23));
    expect(at(DateTime(2026, 3, 30, 9)), DateTime(2026, 3, 23));
    expect(at(DateTime(2026, 3, 29, 15, 59)), isNull);
  });
}
