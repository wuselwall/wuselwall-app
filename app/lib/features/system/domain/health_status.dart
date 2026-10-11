/// Result of `api.health()`.
class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.serverTime,
    required this.dbVersion,
  });

  factory HealthStatus.fromJson(Object? json) {
    final map = json! as Map<String, dynamic>;
    return HealthStatus(
      status: map['status'] as String,
      serverTime: DateTime.parse(map['server_time'] as String),
      dbVersion: map['db_version'] as String,
    );
  }

  final String status;
  final DateTime serverTime;
  final String dbVersion;

  bool get isOk => status == 'ok';
}
