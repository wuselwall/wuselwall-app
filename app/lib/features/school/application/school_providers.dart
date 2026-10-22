import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/data/proposals_repository.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/proposal_models.dart';
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

/// The open proposals an assistant handed the family (specs/24), for guardians. A
/// failure (a server without proposals, offline) shows none: they are a courtesy. Refetched
/// with the school topic, which the server broadcasts on every proposal.
final openProposalsProvider = FutureProvider.autoDispose<List<ProposalRecord>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'school');
  }
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final acting = ref.watch(actingProfileProvider);
  final guardian = members.any((m) => m.id == acting && m.isGuardian);
  if (!guardian) return const [];
  final result = await ref.watch(proposalsRepositoryProvider).open();
  return result.valueOrNull ?? const [];
});

/// The school year around [day], as the region's schools count it: from 1 August to
/// 31 July (specs/24 "Fewer required facts"). The term a family gets without being asked.
({DateTime from, DateTime to, int startYear}) schoolYearAround(DateTime day) {
  final startYear = day.month >= 8 ? day.year : day.year - 1;
  return (
    from: DateTime(startYear, 8),
    to: DateTime(startYear + 1, 7, 31),
    startYear: startYear,
  );
}
