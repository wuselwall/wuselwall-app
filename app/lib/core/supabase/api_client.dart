import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/result.dart';

/// The only way feature repositories talk to the backend.
///
/// Reads go through `api` views, writes through `api` functions (one function = one
/// transaction), and Edge Functions through [function]. Each call returns a [Result],
/// so errors are values from here on up.
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

  /// Calls the Edge Function [name] with a JSON POST [body] and parses its reply. The
  /// caller's JWT is forwarded by the client, so the function runs under RLS.
  Future<Result<T>> function<T>(
    String name, {
    Map<String, dynamic>? body,
    required T Function(Object? json) parse,
  }) => Result.guard(() async {
    try {
      final response = await _client.functions.invoke(name, body: body);
      return parse(response.data);
    } on FunctionException catch (error) {
      throw functionError(name, error);
    }
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

/// What an Edge Function failure looks like to the error mapper, so it becomes the same
/// [Failure] an `api` function's would. A transport failure (status 0) becomes a
/// network error. A JSON reply carrying `code` (SQLSTATE) and `hint` keeps them; without
/// them the HTTP status stands in for the SQLSTATE the `api` functions would raise
/// (401 auth, 403 permission, 404 not found, 400 and 422 invalid input). A function that
/// is not deployed at all is "not found" too.
Object functionError(String name, FunctionException error) {
  if (error.status == 0) {
    return http.ClientException('Edge Function $name unreachable');
  }
  final details = error.details is Map
      ? error.details as Map<Object?, Object?>
      : const <Object?, Object?>{};
  final code = details['code'] as String?;
  final sqlState =
      // The functions router's own reply when the function is not deployed: a server
      // older than the function.
      (code == 'NOT_FOUND' ? 'PGRST202' : code) ??
      switch (error.status) {
        401 => 'PGRST301',
        403 => '42501',
        404 => 'PGRST202',
        400 ||
        422 => '22023', // invalid parameter value: input the function rejected
        _ => '${error.status}',
      };
  return PostgrestException(
    message: 'Edge Function $name failed with status ${error.status}',
    code: sqlState,
    hint: details['hint'] as String?,
    details: error.details,
  );
}
