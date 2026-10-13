import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';

/// One call the tasks repository made: an `api` function name (or `fn:<edge function>`)
/// and its parameters.
typedef TasksCall = ({String name, Map<String, dynamic>? params});

/// A stand-in for the `api` layer of the tasks module. The real `TasksRepository` runs
/// on top of it, so tests see the parameters the app sends and the rows it renders.
/// Views answer from [tables]; functions answer from [replies], with a sensible default
/// per function. Unknown views are empty; unknown functions fail as not found.
class FakeTasksApi implements ApiClient {
  FakeTasksApi({
    Map<String, List<Map<String, dynamic>>>? tables,
    Map<String, Object?>? replies,
  }) : tables = {
         'task_definitions': const [],
         'task_instances': const [],
         'point_balances': const [],
         'point_transactions': const [],
         'rewards': const [],
         'reward_redemptions': const [],
         'streaks': const [],
         ...?tables,
       },
       replies = {..._defaults, ...?replies};

  /// Rows of each `api` view, in snake_case as the database returns them.
  final Map<String, List<Map<String, dynamic>>> tables;

  /// What each `api` function answers with, as JSON.
  final Map<String, Object?> replies;

  /// Every call, in order.
  final calls = <TasksCall>[];

  /// The calls to one function, in order.
  List<TasksCall> named(String name) => [
    for (final c in calls)
      if (c.name == name) c,
  ];

  static const _defaults = <String, Object?>{
    'task_complete': {'status': 'done', 'points_credited': 1},
    'task_undo': {'status': 'open', 'points_credited': 0},
    'task_definition_save': {'id': 'd-new'},
    'reward_save': {'id': 'r-new'},
    'reward_request': {'id': 'rd-new', 'status': 'requested'},
    'tasks-materialise': {'created': 0},
  };

  /// Failures to answer with, by function name.
  final failures = <String, Failure>{};

  @override
  Future<Result<T>> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Object? json) parse,
  }) async {
    calls.add((name: fn, params: params));
    final failure = failures[fn];
    if (failure != null) return Err(failure);
    if (!replies.containsKey(fn)) {
      return Err(NotFoundFailure(code: fn));
    }
    try {
      return Ok(parse(replies[fn]));
    } on Object catch (error) {
      return Err(UnknownFailure(cause: error));
    }
  }

  @override
  Future<Result<T>> function<T>(
    String name, {
    Map<String, dynamic>? body,
    required T Function(Object? json) parse,
  }) async {
    calls.add((name: 'fn:$name', params: body));
    return Ok(parse(replies[name]));
  }

  @override
  Future<Result<List<T>>> select<T>(
    String view, {
    String columns = '*',
    PostgrestTransformBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> query,
    )?
    build,
    required T Function(Map<String, dynamic> row) parse,
  }) async {
    calls.add((name: 'view:$view', params: null));
    return Ok([
      for (final row in tables[view] ?? const <Map<String, dynamic>>[])
        parse(row),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A definition row as the `api.task_definitions` view returns it.
Map<String, dynamic> definitionRow({
  required String id,
  required String title,
  String kind = 'duty',
  int points = 1,
  String assignment = 'rotating',
  List<String> assignees = const [],
  bool verification = false,
  String? rrule,
  String? iconKey,
}) => {
  'id': id,
  'title': title,
  'kind': kind,
  'points': points,
  'starts_on': '2026-10-01',
  'window_days': 1,
  'assignment': assignment,
  'assignee_profile_ids': assignees,
  'requires_verification': verification,
  'is_active': true,
  'rrule': rrule,
  'icon_key': iconKey,
};

/// An instance row due today (2026-10-14 in the tests' clock).
Map<String, dynamic> instanceRow({
  required String id,
  required String title,
  String? assignee,
  String status = 'open',
  int points = 1,
  String kind = 'duty',
  bool verification = false,
  String? completedBy,
  String? definitionId,
  String? iconKey,
  String dueOn = '2026-10-14',
  String? closesOn,
}) => {
  'id': id,
  'definition_id': definitionId,
  'title': title,
  'kind': kind,
  'points': points,
  'icon_key': iconKey,
  'due_on': dueOn,
  'opens_on': dueOn,
  'closes_on': closesOn ?? dueOn,
  'assigned_profile_id': assignee,
  'status': status,
  'completion_count': status == 'open' ? 0 : 1,
  'completed_by_profile_id': completedBy,
  'completed_at': status == 'open' ? null : '2026-10-14T08:00:00Z',
  'requires_verification': verification,
};
