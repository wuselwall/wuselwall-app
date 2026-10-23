import 'package:wuselwall/features/school/domain/timetable_import.dart';

/// A proposal as `api.proposals` returns it (specs/24 "Proposals"): a payload an
/// assistant handed the family, waiting for a guardian's verdict in the app. Only
/// timetables for now; a kind this app does not know is not shown.
class ProposalRecord {
  const ProposalRecord({
    required this.id,
    required this.kind,
    required this.payload,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.proposedByProfileId,
    this.assistantLabel,
    this.summary,
  });

  /// Null for a row this app cannot show (unknown kind or status).
  static ProposalRecord? fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    final status = json['status'] as String?;
    final payload = json['payload'];
    if (kind != 'timetable' || status == null || payload is! Map) return null;
    return ProposalRecord(
      id: json['id'] as String,
      kind: 'timetable',
      payload: payload.cast<String, dynamic>(),
      source: json['source'] as String? ?? 'mcp',
      status: status,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      proposedByProfileId: json['proposed_by_profile_id'] as String?,
      assistantLabel: json['assistant_label'] as String?,
      summary: json['summary'] as String?,
    );
  }

  final String id;
  final String kind;
  final Map<String, dynamic> payload;

  /// 'mcp' or 'scan'.
  final String source;

  /// 'open', 'applied', 'rejected' or 'expired'.
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? proposedByProfileId;

  /// The assistant key's label ("Claude"), so the family knows which assistant spoke.
  final String? assistantLabel;
  final String? summary;

  bool get isOpen => status == 'open';

  /// The member the payload names, if any.
  String? get memberName => payload['member'] as String?;

  /// The payload read as a timetable; null when it does not parse (a newer format).
  TimetableImport? get timetable {
    try {
      return parseTimetableImportJson(payload);
    } on ImportParseException {
      return null;
    }
  }
}
