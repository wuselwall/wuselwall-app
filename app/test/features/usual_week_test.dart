import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/usual_week.dart';

UsualPlace slot(int from, int to, [PresenceState s = PresenceState.working]) =>
    UsualPlace(
      state: s,
      starts: TimeOfDay(hour: from, minute: 0),
      ends: TimeOfDay(hour: to, minute: 0),
    );

const wholeDay = UsualPlace(state: PresenceState.homeOffice);

void main() {
  group('usualDayValid', () {
    test('nothing, one whole day, or up to three slots that fit', () {
      expect(usualDayValid(const []), isTrue);
      expect(usualDayValid(const [wholeDay]), isTrue);
      expect(usualDayValid([slot(8, 12)]), isTrue);
      expect(usualDayValid([slot(13, 17), slot(8, 12), slot(12, 13)]), isTrue);
    });

    test('refuses what the server refuses', () {
      expect(usualDayValid([wholeDay, slot(8, 12)]), isFalse);
      expect(usualDayValid([slot(8, 12), slot(11, 14)]), isFalse);
      expect(usualDayValid([slot(12, 8)]), isFalse);
      expect(
        usualDayValid([slot(6, 7), slot(8, 9), slot(10, 11), slot(12, 13)]),
        isFalse,
      );
    });
  });

  group('alternating weeks', () {
    final week = UsualWeek(
      profileId: 'a',
      anchor: DateTime(2026, 10, 19),
      slots: const [
        UsualSlot(weekday: 1, place: wholeDay),
        UsualSlot(
          week: 1,
          weekday: 1,
          place: UsualPlace(state: PresenceState.off),
        ),
      ],
    );

    test(
      'weeks alternate from the anchor, before it too and across a week 53',
      () {
        expect(week.weekOf(DateTime(2026, 10, 21)), 0);
        expect(week.weekOf(DateTime(2026, 10, 26)), 1);
        expect(week.weekOf(DateTime(2026, 10, 12)), 1);
        expect(week.weekOf(DateTime(2026, 12, 28)), 0); // KW 53
        expect(week.weekOf(DateTime(2027, 1, 4)), 1); // KW 1
        expect(
          const UsualWeek(profileId: 'a').weekOf(DateTime(2026, 10, 26)),
          0,
        );
      },
    );

    test(
      'switching alternating off keeps week B, a day edit keeps the rest',
      () {
        final single = week.withAnchor(null);
        expect(single.anchor, isNull);
        expect(single.slots.map((s) => s.week), [0, 1]);
        expect(single.weekOf(DateTime(2026, 10, 26)), 0);

        final edited = week.withDay(2, const [wholeDay]);
        expect(edited.day(1, week: 1).single.state, PresenceState.off);
        expect(edited.day(1).single.state, PresenceState.homeOffice);
        expect(edited.day(2).single.state, PresenceState.homeOffice);
      },
    );
  });
}
