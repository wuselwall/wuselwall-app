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
    // GoTrue wraps browser fetch/CORS failures; no session was rejected here.
    AuthRetryableFetchException() ||
    AuthUnknownException(
      originalError: http.ClientException(),
    ) => NetworkFailure(cause: error),
    AuthException() => AuthFailure(code: _authCode(error), cause: error),
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

/// An error carried back in a redirect URL has the OAuth `error` (for example
/// `access_denied`) in [AuthException.code] and Supabase's specific `error_code` (for
/// example `signup_disabled`) in [AuthException.statusCode]; the specific one wins.
String? _authCode(AuthException e) {
  final status = e.statusCode;
  if (status != null && int.tryParse(status) == null) return status;
  // A refusal by the server's Before User Created hook (specs/20 "Claiming the server")
  // arrives with the code `unknown` and the hook's message as the text: that message is
  // the stable code (`setup_key_required`).
  if ((e.code == null || e.code == 'unknown') &&
      _codeLike.hasMatch(e.message)) {
    return e.message;
  }
  return e.code;
}

final _codeLike = RegExp(r'^[a-z][a-z0-9_]{2,40}$');

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
