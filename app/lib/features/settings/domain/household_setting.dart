/// Who a setting belongs to (specs/21): the household, one member or one device.
enum SettingScope {
  household,
  member,
  device;

  static SettingScope parse(String wire) => switch (wire) {
    'household' => SettingScope.household,
    'member' => SettingScope.member,
    'device' => SettingScope.device,
    _ => throw FormatException('Unknown setting scope "$wire"'),
  };
}

/// The shape of a setting's value. The wire names match `app.setting_definition.type`.
enum SettingType {
  boolean,
  integer,
  time,
  enumeration,
  weekdayTime,
  timeRange,
  times,
  region;

  /// Null for a type this app does not know: a newer server may add one (specs/21), and
  /// that row is skipped rather than failing the whole list.
  static SettingType? tryParse(String wire) => switch (wire) {
    'boolean' => SettingType.boolean,
    'integer' => SettingType.integer,
    'time' => SettingType.time,
    'enum' => SettingType.enumeration,
    'weekday_time' => SettingType.weekdayTime,
    'time_range' => SettingType.timeRange,
    'times' => SettingType.times,
    'region' => SettingType.region,
    _ => null,
  };

  static SettingType parse(String wire) =>
      tryParse(wire) ?? (throw FormatException('Unknown setting type "$wire"'));
}

/// One row of `api.settings`: a catalogue definition with its effective value.
///
/// The view returns every definition once for the household, plus one row per member or
/// device override. [profileId] and [deviceId] are null on the household-level rows.
/// [value] is null only for a nullable setting that is switched off.
class SettingEntry {
  const SettingEntry({
    required this.key,
    required this.scope,
    required this.type,
    required this.constraints,
    required this.selfService,
    required this.defaultValue,
    required this.value,
    required this.isDefault,
    this.profileId,
    this.deviceId,
  });

  /// The rows of `api.settings` this app can show: those of an unknown scope or type are
  /// left out (see [SettingType.tryParse]).
  static List<SettingEntry> fromRows(Iterable<Map<String, dynamic>> rows) => [
    for (final row in rows)
      if (_known(row)) SettingEntry.fromJson(row),
  ];

  static bool _known(Map<String, dynamic> json) =>
      SettingType.tryParse(json['type'] as String? ?? '') != null &&
      const {'household', 'member', 'device'}.contains(json['scope']);

  factory SettingEntry.fromJson(Map<String, dynamic> json) => SettingEntry(
    key: json['key'] as String,
    scope: SettingScope.parse(json['scope'] as String),
    type: SettingType.parse(json['type'] as String),
    constraints:
        (json['constraints'] as Map?)?.cast<String, dynamic>() ?? const {},
    selfService: json['self_service'] as bool? ?? false,
    defaultValue: json['default_value'],
    value: json['value'],
    isDefault: json['is_default'] as bool? ?? true,
    profileId: json['profile_id'] as String?,
    deviceId: json['device_id'] as String?,
  );

  final String key;
  final SettingScope scope;
  final SettingType type;
  final Map<String, dynamic> constraints;
  final bool selfService;
  final Object? defaultValue;
  final Object? value;
  final bool isDefault;
  final String? profileId;
  final String? deviceId;

  /// Inclusive bounds of an integer setting.
  int? get min => (constraints['min'] as num?)?.toInt();
  int? get max => (constraints['max'] as num?)?.toInt();

  /// The allowed values of an enum setting, in display order.
  List<String> get enumValues => [
    for (final v in (constraints['values'] as List?) ?? const []) v as String,
  ];

  /// Whether JSON null (switched off) is a legal value.
  bool get nullable => constraints['nullable'] == true;
}
