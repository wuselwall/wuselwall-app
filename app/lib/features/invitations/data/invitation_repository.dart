import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// Inviting and joining (J2). Holds no rules: the `api.invitation_*` functions do. Refusals a
/// person can correct come back as values (`PreviewRefused`, `AcceptRefused`); account state
/// (already in a household, a device user) comes back as a failure with that hint as its code.
abstract class InvitationRepository {
  /// A guardian's invitation for an existing adult ([profileId]) or for a new one
  /// ([displayName], with [role]). The token and code come back once.
  Future<Result<CreatedInvitation>> create({
    String? profileId,
    String? displayName,
    required InvitationRole role,
    String? email,
  });

  /// Withdraws an open invitation.
  Future<Result<void>> revoke(String id);

  /// The household's invitations that are still open.
  Future<Result<List<OpenInvitation>>> open();

  /// The household's name, for the share message.
  Future<Result<String>> householdName();

  /// What a secret (token or code) names. Anyone may ask; the answer reveals little.
  Future<Result<PreviewOutcome>> preview(String secret);

  /// Joins the household by [secret] or by the [invitationId] of a pending invitation.
  /// The session is refreshed, so the token carries the new device's claims.
  Future<Result<AcceptOutcome>> accept({
    String? secret,
    String? invitationId,
    required String displayName,
    String? colorHex,
    required String deviceLabel,
  });
}

class ApiInvitationRepository implements InvitationRepository {
  const ApiInvitationRepository(this._api, this._auth);

  final ApiClient _api;
  final GoTrueClient _auth;

  @override
  Future<Result<CreatedInvitation>> create({
    String? profileId,
    String? displayName,
    required InvitationRole role,
    String? email,
  }) => _api.rpc(
    'invitation_create',
    params: {
      'p_actor': null,
      'p_profile': profileId,
      'p_display_name': displayName?.trim(),
      'p_role': role.wire,
      'p_email': email?.trim(),
    },
    parse: (json) => CreatedInvitation.fromJson(json! as Map<String, dynamic>),
  );

  @override
  Future<Result<void>> revoke(String id) => _api.rpc(
    'invitation_revoke',
    params: {'p_actor': null, 'p_id': id},
    parse: (_) {},
  );

  @override
  Future<Result<List<OpenInvitation>>> open() async {
    final rows = await _api.select<OpenInvitation>(
      'invitations',
      build: (query) => query.order('created_at'),
      parse: OpenInvitation.fromJson,
    );
    return rows.map((list) => list.where((i) => i.isOpen).toList());
  }

  @override
  Future<Result<String>> householdName() async {
    final rows = await _api.select<String>(
      'household',
      columns: 'name',
      parse: (row) => row['name'] as String,
    );
    return rows.map((names) => names.first);
  }

  @override
  Future<Result<PreviewOutcome>> preview(String secret) => _api.rpc(
    'invitation_preview',
    params: {'p_token_or_code': secret},
    parse: (json) {
      final map = json! as Map<String, dynamic>;
      return map['ok'] == true
          ? PreviewValid(InvitationPreview.fromJson(map))
          : PreviewRefused(map['reason'] as String? ?? 'invalid');
    },
  );

  @override
  Future<Result<AcceptOutcome>> accept({
    String? secret,
    String? invitationId,
    required String displayName,
    String? colorHex,
    required String deviceLabel,
  }) async {
    final joined = await _api.rpc<AcceptOutcome>(
      'invitation_accept',
      params: {
        'p_token_or_code': secret,
        'p_invitation_id': invitationId,
        'p_display_name': displayName.trim(),
        'p_color': colorHex,
        'p_device_label': deviceLabel.trim(),
      },
      parse: (json) {
        final map = json! as Map<String, dynamic>;
        if (map['ok'] != true) {
          return AcceptRefused(map['reason'] as String? ?? 'invalid');
        }
        return Accepted(
          householdId: map['household_id'] as String,
          profileId: map['profile_id'] as String,
          deviceId: map['device_id'] as String,
        );
      },
    );
    if (joined case Ok(value: Accepted())) {
      // The new device's claims arrive with the next token.
      final refreshed = await Result.guard(_auth.refreshSession);
      return refreshed.map((_) => joined.unwrap());
    }
    return joined;
  }
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => ApiInvitationRepository(
    ref.watch(apiClientProvider),
    ref.watch(supabaseClientProvider).auth,
  ),
);

/// The invitation kept on this phone between the front door and the join confirmation.
abstract class InvitationStore {
  Future<StoredInvitation?> read();
  Future<void> write(StoredInvitation invitation);
  Future<void> clear();
}

/// Kept in the platform's secure storage. Every failure reads as "nothing kept": the
/// invitee can always type the code again.
class SecureInvitationStore implements InvitationStore {
  const SecureInvitationStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'wuselwall.invitation.pending';

  @override
  Future<StoredInvitation?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return StoredInvitation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (error, stack) {
      logError(
        'Reading the kept invitation failed',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  @override
  Future<void> write(StoredInvitation invitation) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(invitation.toJson()));
    } on Object catch (error, stack) {
      logError(
        'Keeping the invitation failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (error, stack) {
      logError(
        'Clearing the invitation failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

final invitationStoreProvider = Provider<InvitationStore>(
  (ref) => const SecureInvitationStore(),
);
