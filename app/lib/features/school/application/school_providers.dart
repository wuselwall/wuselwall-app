import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// Everything the Stundenplan reads through the views. Refetched when another device
/// changes the school (the `school` topic).
final schoolDataProvider = FutureProvider.autoDispose<SchoolData>((ref) async {
  ref.watch(deviceKeyProvider);
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'school');
  }
  return (await ref.watch(schoolRepositoryProvider).all()).unwrap();
});

/// The projected days from `school-week` for an inclusive date range. A record key, so
/// the section can ask for the week and for tomorrow alike.
final schoolWeekProvider = FutureProvider.autoDispose
    .family<SchoolWeek, (DateTime, DateTime)>((ref, range) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'school');
      }
      final (from, to) = range;
      return (await ref
              .watch(schoolRepositoryProvider)
              .week(from: from, to: to))
          .unwrap();
    });

/// The children the Stundenplan shows: active members who have a timetable. A
/// household with none yet shows its children (`profile.kind`), so a timetable can be
/// entered for the first time.
final schoolChildrenProvider = Provider<AsyncValue<List<Member>>>((ref) {
  final members = ref.watch(membersProvider);
  final data = ref.watch(schoolDataProvider);
  return members.whenData((all) {
    final active = all.where((m) => m.active).toList();
    final withTimetable = data.value == null
        ? const <String>{}
        : {for (final t in data.value!.timetables) t.profileId};
    final withSchool = active
        .where((m) => withTimetable.contains(m.id))
        .toList();
    if (withSchool.isNotEmpty) return withSchool;
    return active.where((m) => m.isChild).toList();
  });
});

/// The child on screen; null means the first of [schoolChildrenProvider].
final selectedChildIdProvider =
    NotifierProvider<SelectedChildNotifier, String?>(SelectedChildNotifier.new);

class SelectedChildNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void select(String id) => state = id;
}

/// The Monday of the week on screen.
final selectedWeekProvider = NotifierProvider<SelectedWeekNotifier, DateTime>(
  SelectedWeekNotifier.new,
);

class SelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => mondayOf(DateTime.now());

  void previous() => state = state.subtract(const Duration(days: 7));
  void next() => state = state.add(const Duration(days: 7));
  void thisWeek() => state = mondayOf(DateTime.now());
}

/// Monday of the ISO week of [day], at midnight.
DateTime mondayOf(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - 1));
}
