import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// Reads the Stundenplan's `api` views and `school-week`; writes through the `api`
/// functions of the contract. Every write names the acting profile (`p_actor`); the
/// server decides who may make it (guardians, or members when the household setting
/// allows exception writes).
class SchoolRepository {
  const SchoolRepository(this._api);

  final ApiClient _api;

  Future<Result<List<SchoolRecord>>> schools() => _api.select(
    'schools',
    parse: SchoolRecord.fromJson,
    build: (q) => q.order('name'),
  );

  Future<Result<List<PeriodRecord>>> periods() => _api.select(
    'school_periods',
    parse: PeriodRecord.fromJson,
    build: (q) => q.order('starts_at'),
  );

  Future<Result<List<TermRecord>>> terms() => _api.select(
    'school_terms',
    parse: TermRecord.fromJson,
    build: (q) => q.order('starts_on'),
  );

  Future<Result<List<SubjectRecord>>> subjects() => _api.select(
    'subjects',
    parse: SubjectRecord.fromJson,
    build: (q) => q.order('name'),
  );

  Future<Result<List<TimetableRecord>>> timetables() =>
      _api.select('timetables', parse: TimetableRecord.fromJson);

  Future<Result<List<LessonRecord>>> lessons() => _api.select(
    'timetable_lessons',
    parse: LessonRecord.fromJson,
    build: (q) => q.order('weekday').order('period_index'),
  );

  Future<Result<List<ExceptionRecord>>> exceptions() => _api.select(
    'timetable_exceptions',
    parse: ExceptionRecord.fromJson,
    build: (q) => q.order('on_date'),
  );

  Future<Result<List<HolidayRecord>>> holidays() => _api.select(
    'school_holidays',
    parse: HolidayRecord.fromJson,
    build: (q) => q.order('starts_on'),
  );

  /// All eight views, for the section, the editor and the setup page. A failure of any
  /// view fails the set (the views are read together).
  Future<Result<SchoolData>> all() => Result.guard(
    () async => SchoolData(
      schools: (await schools()).unwrap(),
      periods: (await periods()).unwrap(),
      terms: (await terms()).unwrap(),
      subjects: (await subjects()).unwrap(),
      timetables: (await timetables()).unwrap(),
      lessons: (await lessons()).unwrap(),
      exceptions: (await exceptions()).unwrap(),
      holidays: (await holidays()).unwrap(),
    ),
  );

  /// The projected school days (inclusive, at most 62) and the timetables valid on
  /// [from], from the `school-week` Edge Function.
  Future<Result<SchoolWeek>> week({
    required DateTime from,
    required DateTime to,
  }) => _api.function(
    'school-week',
    body: {'from': ymd(from), 'to': ymd(to)},
    parse: (json) => SchoolWeek.fromJson(json! as Map<String, dynamic>),
  );

  /// [timezone] is sent only when given: the server takes the household's for a new
  /// school and keeps the stored value of an existing one.
  Future<Result<String>> saveSchool({
    required String? actor,
    String? id,
    required String name,
    String? stateCode,
    String? timezone,
  }) => _api.rpc(
    'school_save',
    params: {
      'p_actor': actor,
      'p_school': {
        'id': ?id,
        'name': name,
        'state_code': stateCode,
        'timezone': ?timezone,
      },
    },
    parse: _id,
  );

  /// Replaces the school's bell times (lessons and breaks, in order).
  Future<Result<void>> setPeriods({
    required String? actor,
    required String schoolId,
    required List<PeriodRecord> periods,
  }) => _api.rpc(
    'school_periods_set',
    params: {
      'p_actor': actor,
      'p_school_id': schoolId,
      'p_periods': [for (final p in periods) p.toJson()],
    },
    parse: (_) {},
  );

  Future<Result<String>> saveTerm({
    required String? actor,
    required TermRecord term,
  }) => _api.rpc(
    'school_term_save',
    params: {
      'p_actor': actor,
      'p_term': term.toJson(id: term.id),
    },
    parse: _id,
  );

  Future<Result<String>> saveSubject({
    required String? actor,
    required SubjectRecord subject,
  }) => _api.rpc(
    'subject_save',
    params: {'p_actor': actor, 'p_subject': subject.toJson()},
    parse: _id,
  );

  /// Refused with `subject_in_use` while a timetable still uses the subject.
  Future<Result<void>> deleteSubject({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'subject_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  /// Metadata of a timetable (class, week rhythm, validity). A null [TimetableRecord.id]
  /// creates it.
  Future<Result<String>> saveTimetable({
    required String? actor,
    required TimetableRecord timetable,
  }) => _api.rpc(
    'timetable_save',
    params: {'p_actor': actor, 'p_timetable': timetable.toMetaJson()},
    parse: _id,
  );

  /// Replaces the whole grid of [timetableId] at once.
  Future<Result<void>> setLessons({
    required String? actor,
    required String timetableId,
    required List<LessonRecord> lessons,
  }) => _api.rpc(
    'timetable_lessons_set',
    params: {
      'p_actor': actor,
      'p_timetable_id': timetableId,
      'p_lessons': [for (final l in lessons) l.toJson()],
    },
    parse: (_) {},
  );

  /// Copies metadata and lessons of [fromTimetableId] into a new timetable for
  /// [profileId] in [termId].
  Future<Result<String>> copyTimetable({
    required String? actor,
    required String fromTimetableId,
    required String profileId,
    required String termId,
  }) => _api.rpc(
    'timetable_copy',
    params: {
      'p_actor': actor,
      'p_from_timetable_id': fromTimetableId,
      'p_profile_id': profileId,
      'p_term_id': termId,
    },
    parse: _id,
  );

  /// Enters or updates an exception (`cancelled`, `substituted`, `room_change`,
  /// `extra`). Changes name their [ExceptionRecord.periodIndex].
  Future<Result<String>> saveException({
    required String? actor,
    required ExceptionRecord exception,
  }) => _api.rpc(
    'timetable_exception_save',
    params: {'p_actor': actor, 'p_exception': exception.toJson()},
    parse: _id,
  );

  Future<Result<void>> deleteException({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'timetable_exception_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  Future<Result<String>> saveHoliday({
    required String? actor,
    required HolidayRecord holiday,
  }) => _api.rpc(
    'school_holiday_save',
    params: {
      'p_actor': actor,
      'p_holiday': holiday.toJson(id: holiday.id),
    },
    parse: _id,
  );

  Future<Result<void>> deleteHoliday({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'school_holiday_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );
}

String _id(Object? json) => (json! as Map<String, dynamic>)['id'] as String;

final schoolRepositoryProvider = Provider<SchoolRepository>(
  (ref) => SchoolRepository(ref.watch(apiClientProvider)),
);
