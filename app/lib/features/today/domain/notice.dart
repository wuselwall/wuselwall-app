/// What a notice on the adult Today tab tells (specs/20 J2 and J4).
enum NoticeKind {
  /// An invited adult joined the household (shown to guardians).
  join('join'),

  /// The account signed in on another device (shown on its other personal devices).
  signIn('signin');

  const NoticeKind(this.wire);

  final String wire;

  /// Null for a kind this app does not know yet (a newer server): it is not shown.
  static NoticeKind? parse(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// One notice. The server derives it from the audit log and the device list; [key]
/// identifies it for dismissal, and [name] is the joiner's name or the new device's label.
class AppNotice {
  const AppNotice({
    required this.key,
    required this.kind,
    required this.name,
    required this.at,
  });

  final String key;
  final NoticeKind kind;
  final String name;
  final DateTime at;

  /// Null for a notice this app cannot show (unknown kind, or a row without a key).
  static AppNotice? fromJson(Map<String, dynamic> json) {
    final kind = NoticeKind.parse(json['kind'] as String?);
    final key = json['key'] as String?;
    if (kind == null || key == null) return null;
    return AppNotice(
      key: key,
      kind: kind,
      name: (json['name'] as String?) ?? '',
      at:
          DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
