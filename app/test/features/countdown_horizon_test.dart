import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Inclusive days of a window, as the `occurrences` function counts them.
int _length(({DateTime from, DateTime to}) w) =>
    DateTime.utc(
      w.to.year,
      w.to.month,
      w.to.day,
    ).difference(DateTime.utc(w.from.year, w.from.month, w.from.day)).inDays +
    1;

void main() {
  final today = DateTime(2026, 10, 24);

  group('countdownWindow', () {
    test('a short horizon looks back two weeks', () {
      final w = countdownWindow(today, 14);
      expect(w.from, DateTime(2026, 10, 10));
      expect(w.to, DateTime(2026, 11, 7));
    });

    test('every allowed horizon fits the server\'s 62 days', () {
      for (var days = 7; days <= 60; days++) {
        final w = countdownWindow(today, days);
        expect(_length(w), lessThanOrEqualTo(maxOccurrenceWindowDays));
        expect(w.from.isAfter(today), isFalse, reason: '$days');
        expect(
          w.to,
          DateTime(today.year, today.month, today.day + days),
          reason: '$days',
        );
      }
    });

    test('the longest horizon, 60 days, keeps a day back', () {
      final w = countdownWindow(today, 60);
      expect(_length(w), 62);
      expect(w.from, DateTime(2026, 10, 23));
    });
  });

  test('with rituals.countdown_days at 60 a marked event 50 days ahead still counts down', () async {
    final asked = <({DateTime from, DateTime to})>[];
    final zoo = Occurrence(
      id: 'zoo',
      eventId: 'zoo',
      calendarId: 'c',
      title: 'Zoo',
      kind: EventKind.appointment,
      status: EventStatus.confirmed,
      importance: Importance.normal,
      allDay: true,
      start: DateTime(2026, 12, 13),
      end: DateTime(2026, 12, 13),
      localStartDate: DateTime(2026, 12, 13),
      localEndDate: DateTime(2026, 12, 13),
      countdown: true,
    );
    final container = ProviderContainer(
      overrides: [
        ritualTodayProvider.overrideWithValue(today),
        countdownHorizonProvider.overrideWithValue(60),
        lighterDayProvider.overrideWithValue(
          resolveLighterDay(
            entries: const [],
            register: UiRegister.kiosk,
            deviceId: null,
            acting: null,
          ),
        ),
        membersProvider.overrideWith((ref) async => const <Member>[]),
        schoolDataProvider.overrideWith(
          (ref) => Completer<SchoolData>().future,
        ),
        // The server's rule: more than 62 days is refused.
        occurrencesProvider.overrideWith((ref, window) async {
          asked.add(window);
          if (_length(window) > 62) {
            throw const ValidationFailure(code: 'window_invalid');
          }
          return OccurrenceWindow(
            timezone: 'Europe/Berlin',
            occurrences: [zoo],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(countdownsProvider, (_, _) {});
    await pumpEventQueue();
    expect(asked, isNotEmpty);
    expect(sub.read().map((c) => c.title), ['Zoo']);
  });
}
