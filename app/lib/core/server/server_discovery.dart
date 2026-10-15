import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_info.dart';

/// Finds out whether an address is a WuselWall server, and how to talk to it
/// (ADR-018, decision 3). Two places, in this order:
///
/// 1. `/.well-known/wuselwall.json`: servers with a domain of their own, and the web
///    host that serves a server's web app;
/// 2. `/functions/v1/server-info`: every server, hosted Supabase projects included,
///    whose domain cannot serve a file of ours.
///
/// Failures: [NetworkFailure] when neither place answers, [NotFoundFailure] with code
/// `not_wuselwall` when something answers but is not a WuselWall server.
class ServerDiscovery {
  ServerDiscovery({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const paths = [
    '/.well-known/wuselwall.json',
    '/functions/v1/server-info',
  ];

  Future<Result<ServerInfo>> discover(Uri origin) async {
    var reached = false;
    Object? lastError;
    for (final path in paths) {
      try {
        final response = await _client
            .get(
              origin.replace(path: path),
              headers: {'Accept': 'application/json'},
            )
            .timeout(timeout);
        reached = true;
        if (response.statusCode != 200) continue;
        return Ok(
          ServerInfo.fromDiscovery(jsonDecode(response.body), origin: origin),
        );
      } on FormatException catch (e) {
        reached = true;
        lastError = e;
      } on Object catch (e) {
        // Unreachable, TLS, timeout: the other path may still answer.
        lastError = e;
      }
    }
    return Err(
      reached
          ? NotFoundFailure(code: 'not_wuselwall', cause: lastError)
          : NetworkFailure(cause: lastError),
    );
  }
}
