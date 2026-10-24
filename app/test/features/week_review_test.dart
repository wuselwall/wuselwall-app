import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';

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

  test('a highlight carries no number, whatever the server sends', () {
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
}
