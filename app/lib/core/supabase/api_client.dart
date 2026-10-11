import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/result.dart';

/// The only way feature repositories talk to the backend.
///
/// Reads go through `api` views, writes through `api` functions (one function = one
/// transaction). Each call returns a [Result], so errors are values from here on up.
class ApiClient {
  const ApiClient(this._client);

  final SupabaseClient _client;

  /// Calls the `api` function [fn] and parses its JSON result with [parse].
  Future<Result<T>> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Object? json) parse,
  }) => Result.guard(() async {
    final json = await _client.rpc<Object?>(fn, params: params);
    return parse(json);
  });

  /// Reads rows from an `api` view; [build] shapes the query (filters, ordering).
  Future<Result<List<T>>> select<T>(
    String view, {
    String columns = '*',
    PostgrestTransformBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> query,
    )?
    build,
    required T Function(Map<String, dynamic> row) parse,
  }) => Result.guard(() async {
    final base = _client.from(view).select(columns);
    final rows = await (build == null ? base : build(base));
    return rows.map(parse).toList(growable: false);
  });
}
