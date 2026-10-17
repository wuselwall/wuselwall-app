import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/logging/log.dart';

/// Converts any thrown transport or backend error into a [Failure].
///
/// Postgres SQLSTATE classes and PostgREST codes are mapped here once, so features
/// and widgets only ever reason about [Failure] subtypes.
Failure mapError(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) return error;

  final failure = switch (error) {
    PostgrestException() => _fromPostgrest(error),
    AuthException() => AuthFailure(code: error.code, cause: error),
    SocketException() ||
    TimeoutException() ||
    HttpException() ||
    http.ClientException() => NetworkFailure(cause: error),
    _ => UnknownFailure(cause: error),
  };

  if (failure is UnknownFailure) {
    logError('Unmapped error', error: error, stackTrace: stackTrace);
  }
  return failure;
}

Failure _fromPostgrest(PostgrestException e) {
  final code = e.code ?? '';
  // For `raise exception ... using errcode = 'P0001', hint = 'task_already_done'`
  // the hint carries the stable domain code.
  final domainCode = e.hint?.isNotEmpty ?? false ? e.hint : code;

  if (code == 'PGRST301' || code == 'PGRST303') {
    return AuthFailure(code: code, cause: e); // JWT missing, invalid or expired
  }
  if (code == '42501') {
    return PermissionFailure(code: domainCode, cause: e); // RLS / privileges
  }
  if (code == 'PGRST116' || code == 'PGRST202' || code == '42883') {
    return NotFoundFailure(code: domainCode, cause: e);
  }
  if (code == '23505' || code == '40001' || code == '40P01') {
    return ConflictFailure(code: domainCode, cause: e);
  }
  if (code.startsWith('23') || code.startsWith('22') || code == 'P0001') {
    return ValidationFailure(code: domainCode, cause: e);
  }
  return UnknownFailure(code: domainCode, cause: e);
}
