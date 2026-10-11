/// A domain-level error, safe to show to a household member (after localisation).
///
/// Features never see transport exceptions; the error mapper converts them to these.
sealed class Failure {
  const Failure({this.code, this.cause});

  /// Machine-readable code from the backend (for example an `api` function's
  /// `raise exception ... using errcode`), when there is one.
  final String? code;

  /// The original exception, for logs only. Never shown to a user.
  final Object? cause;
}

/// No connection, timeout, DNS failure or an unreachable server.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.code, super.cause});
}

/// Not signed in, session expired, or credentials rejected.
final class AuthFailure extends Failure {
  const AuthFailure({super.code, super.cause});
}

/// Signed in, but this device or profile may not do that (RLS, guardian check).
final class PermissionFailure extends Failure {
  const PermissionFailure({super.code, super.cause});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.code, super.cause});
}

/// The change clashes with existing data, for example a duplicate.
final class ConflictFailure extends Failure {
  const ConflictFailure({super.code, super.cause});
}

/// Input rejected by a database constraint or an `api` function's checks.
final class ValidationFailure extends Failure {
  const ValidationFailure({super.code, super.cause});
}

final class UnknownFailure extends Failure {
  const UnknownFailure({super.code, super.cause});
}
