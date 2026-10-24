import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';

/// Dates, times and names as the week board writes them. One place, so the wall reads
/// the same everywhere: "8:30", "8–14:25", "Mi 2.9.", "Mittwoch, 2. September".
extension BoardFormat on BuildContext {
  String get _locale => Localizations.localeOf(this).toLanguageTag();

  bool get _use24h =>
      Localizations.localeOf(this).languageCode != 'en' ||
      MediaQuery.alwaysUse24HourFormatOf(this);

  /// "8:30", "14:00" (en, 12-hour: "8:30 AM").
  String time(TimeOfDay t) {
    final d = DateTime(2000, 1, 1, t.hour, t.minute);
    return _use24h
        ? DateFormat('H:mm', _locale).format(d)
        : DateFormat('h:mm a', _locale).format(d);
  }

  /// Compact: full hours lose their ":00" — "8", "14:25". In 12-hour English the
  /// meridiem shrinks to one letter, as compact calendars write it: "8a", "2:25p".
  String shortTime(TimeOfDay t) {
    final d = DateTime(2000, 1, 1, t.hour, t.minute);
    if (_use24h) {
      // Not DateFormat('H'): in German a lone hour pattern renders as "08 Uhr".
      return t.minute == 0
          ? '${t.hour}'
          : DateFormat('H:mm', _locale).format(d);
    }
    return '${_twelveHour(t)}${t.period == DayPeriod.am ? 'a' : 'p'}';
  }

  /// An appointment's start in a day column: "14:00" in 24-hour time, "2p" in 12-hour
  /// English, where "2:00 PM" would leave no room for the attendee dots.
  String cellTime(TimeOfDay t) => _use24h ? time(t) : shortTime(t);

  String _twelveHour(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return t.minute == 0 ? '$h' : '$h:${t.minute.toString().padLeft(2, '0')}';
  }

  /// "8–14:25": a span with compact ends. In 12-hour English the start drops its
  /// meridiem when the end shares it: "3–4p", but "8a–2:25p".
  String span(TimeOfDay from, TimeOfDay to) {
    if (!_use24h && from.period == to.period) {
      return '${_twelveHour(from)}–${shortTime(to)}';
    }
    return '${shortTime(from)}–${shortTime(to)}';
  }

  /// "Mi" / "Wed".
  String weekdayShort(DateTime d) =>
      DateFormat.E(_locale).format(d).replaceAll('.', '');

  /// "Mittwoch" / "Wednesday".
  String weekdayLong(DateTime d) => DateFormat.EEEE(_locale).format(d);

  /// "2.9." / "9/2".
  String dayMonth(DateTime d) => DateFormat.Md(_locale).format(d);

  /// "Mittwoch, 2. September" / "Wednesday, September 2".
  String fullDate(DateTime d) => DateFormat.MMMMEEEEd(_locale).format(d);

  /// "Oktober 2026" / "October 2026": the calendar's month view title.
  String monthYear(DateTime d) => DateFormat.yMMMM(_locale).format(d);

  /// "Okt. 2026" / "Oct 2026": the month view's title in a phone's narrow bar.
  String monthYearShort(DateTime d) => DateFormat.yMMM(_locale).format(d);

  /// "19. Okt. 2026" / "Oct 19, 2026": a date with its year, as a form field shows it.
  String mediumDate(DateTime d) => DateFormat.yMMMd(_locale).format(d);

  /// The household's own label for a presence state, or the state's name.
  String presenceLabel(PresenceState state, [String? label]) {
    if (label != null && label.trim().isNotEmpty) return label;
    final l10n = this.l10n;
    return switch (state) {
      PresenceState.working => l10n.presenceWorking,
      PresenceState.homeOffice => l10n.presenceHomeOffice,
      PresenceState.travel => l10n.presenceTravel,
      PresenceState.away => l10n.presenceAway,
      PresenceState.off => l10n.presenceOff,
      PresenceState.childcare => l10n.presenceChildcare,
    };
  }

  /// A usual place: its label, and its times when it is a slot ("Büro 8–12").
  String usualLabel(UsualPlace place) {
    final label = presenceLabel(place.state, place.label);
    return place.isWholeDay
        ? label
        : '$label ${span(place.starts!, place.ends!)}';
  }

  /// A member as the board names them (`board.member_label`).
  String memberName(WeekBoard board, BoardMember m) =>
      board.settings.memberLabel == MemberLabel.initial
      ? m.initial
      : m.displayName;

  String dayPartLabel(DayPart part) => switch (part) {
    DayPart.morning => l10n.boardMorning,
    DayPart.afternoon => l10n.boardAfternoon,
    DayPart.evening => l10n.boardEvening,
  };

  String mealSlotLabel(MealSlot slot) => switch (slot) {
    MealSlot.lunch => l10n.boardMealLunch,
    MealSlot.dinner => l10n.boardMealDinner,
  };
}
