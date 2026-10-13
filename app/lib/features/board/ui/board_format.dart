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
