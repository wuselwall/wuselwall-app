import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/cache/read_cache.dart';
import 'package:wuselwall/core/error/result.dart';

/// The only way feature repositories talk to the backend.
///
/// Reads go through `api` views, writes through `api` functions (one function = one
/// transaction), and Edge Functions through [function]. Each call returns a [Result],
/// so errors are values from here on up.
///
/// A read given a `cacheKey` survives a restart without network: its last good answer
/// is stored and stands in while the server cannot be reached ([ReadCache]). The key
/// names the read with its arguments (`school-week:2026-11-09:2026-11-10`), so one day's
/// answer is never shown for another. Only reads take one, never a call that changes
/// something.
class ApiClient {
  const ApiClient(this._client, {this._cache});

  final SupabaseClient _client;
  final ReadCache? _cache;

  Future<Result<T>> _read<T>(
    String? cacheKey, {
    required Future<Object?> Function() fetch,
    required T Function(Object? json) parse,
    Duration? patience,
  }) {
    final cache = _cache;
    if (cacheKey == null || cache == null) {
      return Result.guard(() async => parse(await fetch()));
    }
    return cache.through(
      cacheKey,
      fetch: fetch,
      parse: parse,
      patience: patience,
    );
  }

  /// Calls the `api` function [fn] and parses its JSON result with [parse]. With
  /// [patience], a stored answer is used when the server has not answered by then.
  Future<Result<T>> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Object? json) parse,
    String? cacheKey,
    Duration? patience,
  }) => _read(
    cacheKey,
    fetch: () => _client.rpc<Object?>(fn, params: params),
    parse: parse,
    patience: patience,
  );

  /// Calls the Edge Function [name] with a JSON POST [body] and parses its reply. The
  /// caller's JWT is forwarded by the client, so the function runs under RLS.
  Future<Result<T>> function<T>(
    String name, {
    Map<String, dynamic>? body,
    required T Function(Object? json) parse,
    String? cacheKey,
  }) => _read(
    cacheKey,
    fetch: () async {
      try {
        final response = await _client.functions.invoke(name, body: body);
        return response.data as Object?;
      } on FunctionException catch (error) {
        throw functionError(name, error);
      }
    },
    parse: parse,
  );

  /// Reads rows from an `api` view; [build] shapes the query (filters, ordering).
  Future<Result<List<T>>> select<T>(
    String view, {
    String columns = '*',
    PostgrestTransformBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> query,
    )?
    build,
    required T Function(Map<String, dynamic> row) parse,
    String? cacheKey,
  }) => _read(
    cacheKey,
    fetch: () {
      final base = _client.from(view).select(columns);
      return build == null ? base : build(base);
    },
    parse: (json) => [
      for (final row in json! as List<dynamic>)
        parse(Map<String, dynamic>.from(row as Map)),
    ],
  );
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
