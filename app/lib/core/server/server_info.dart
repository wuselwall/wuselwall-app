/// The discovery document of a WuselWall server (ADR-018, decision 3): what the app
/// needs to talk to it, read before anyone signs in. Served by the server's
/// `server-info` function (supabase/functions/_shared/server_info.ts).
class ServerInfo {
  const ServerInfo({
    required this.supabaseUrl,
    required this.publishableKey,
    required this.apiVersion,
    required this.minAppVersion,
    this.householdCreation = 'token',
    this.features = const [],
  });

  /// Reads a discovery document fetched from [origin]. The server names its own
  /// address when it knows it; otherwise it is the origin the document came from.
  /// Throws a [FormatException] for anything that is not a WuselWall document.
  factory ServerInfo.fromDiscovery(Object? json, {required Uri origin}) {
    if (json is! Map<String, Object?> || json['wuselwall'] != 1) {
      throw const FormatException('not a WuselWall discovery document');
    }
    final url = json['supabase_url'];
    final supabaseUrl = url is String ? Uri.tryParse(url) : origin;
    final key = json['publishable_key'];
    final api = json['api_version'];
    final min = json['min_app_version'];
    final features = json['features'];
    if (supabaseUrl == null ||
        !supabaseUrl.hasScheme ||
        supabaseUrl.host.isEmpty ||
        key is! String ||
        key.isEmpty ||
        api is! int ||
        min is! String ||
        !_semver.hasMatch(min)) {
      throw const FormatException('incomplete discovery document');
    }
    return ServerInfo(
      supabaseUrl: Uri(
        scheme: supabaseUrl.scheme,
        host: supabaseUrl.host,
        port: supabaseUrl.hasPort ? supabaseUrl.port : null,
      ),
      publishableKey: key,
      apiVersion: api,
      minAppVersion: min,
      householdCreation: json['household_creation'] as String? ?? 'token',
      features: features is List
          ? features.whereType<String>().toList()
          : const [],
    );
  }

  /// Where the app talks to the server: Auth, PostgREST, Realtime and functions.
  final Uri supabaseUrl;
  final String publishableKey;
  final int apiVersion;
  final String minAppVersion;
  final String householdCreation;
  final List<String> features;

  /// The form the app keeps on the device; [ServerInfo.fromDiscovery] reads it back.
  Map<String, Object?> toJson() => {
    'wuselwall': 1,
    'supabase_url': supabaseUrl.toString(),
    'publishable_key': publishableKey,
    'api_version': apiVersion,
    'min_app_version': minAppVersion,
    'household_creation': householdCreation,
    'sign_in': {'password': true},
    'features': features,
  };

  static final _semver = RegExp(r'^\d+\.\d+\.\d+$');
}
