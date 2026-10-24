import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Whether the household shows birthdays as an occasion: `ambience.birthdays`, on in
/// every country unless switched off (specs/26 "Seasons and occasions").
bool birthdaysShown(LighterDay day) {
  final stored = day.occasionSwitches['ambience.birthdays'];
  return stored != false && stored != 'off';
}

/// The active members whose birthday is on [day] (local), in board order. A 29 February
/// birthday falls on 1 March in other years, as [nextBirthday] has it.
List<Member> birthdaysOn(DateTime day, Iterable<Member> members) {
  final d = DateTime(day.year, day.month, day.day);
  return [
    for (final m in members)
      if (m.active && m.birthday != null && nextBirthday(m.birthday!, d) == d)
        m,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// The birthdays of the seven days from [firstDay], one list per day, for the board's
/// day names ("Paul wird 8", specs/27 "Birthdays"). All empty when the household
/// switched the birthday occasion off, and while the members load.
final weekBirthdaysProvider = Provider.autoDispose
    .family<List<List<Member>>, DateTime>((ref, firstDay) {
      final shown = ref.watch(lighterDayProvider.select(birthdaysShown));
      final members = ref.watch(membersProvider).value ?? const <Member>[];
      return [
        for (var i = 0; i < 7; i++)
          shown
              ? birthdaysOn(
                  DateTime(firstDay.year, firstDay.month, firstDay.day + i),
                  members,
                )
              : const <Member>[],
      ];
    });
