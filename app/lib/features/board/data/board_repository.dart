import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';

/// Reads the week board's read model through the `board-week` Edge Function, which takes
/// `api.board_week` and fills in the week's expanded calendar occurrences — recurrence
/// expansion lives in the Edge Functions, never in SQL or the app (specs/03, ADR-010).
class BoardRepository {
  const BoardRepository(this._api);

  final ApiClient _api;

  /// The board for the week starting on [weekStart] (a Monday). Null asks for the
  /// household's current board week, which honours `board.rollover`.
  Future<Result<WeekBoard>> week({DateTime? weekStart}) => _api.function(
    'board-week',
    body: {'week_start': weekStart == null ? null : _ymd(weekStart)},
    parse: (json) => WeekBoard.fromJson(json! as Map<String, dynamic>),
  );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.watch(apiClientProvider)),
);
