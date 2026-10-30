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
    this.serverVersion,
    this.emailCode = true,
    this.claimed,
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
    final release = json['server_version'];
    final signIn = json['sign_in'];
    final claimed = json['claimed'];
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
      serverVersion: release is String && _semver.hasMatch(release)
          ? release
          : null,
      // Servers from before mail became optional do not say; all of them sent codes.
      emailCode: !(signIn is Map && signIn['email_code'] == false),
      claimed: claimed is bool ? claimed : null,
    );
  }

  /// Where the app talks to the server: Auth, PostgREST, Realtime and functions.
  final Uri supabaseUrl;
  final String publishableKey;
  final int apiVersion;
  final String minAppVersion;
  final String householdCreation;
  final List<String> features;

  /// The server release ("0.2.0"), when the server announces it; servers from before
  /// 0.3.0 and stacks run from a checkout do not.
  final String? serverVersion;

  /// Whether the server mails sign-in codes (`sign_in.email_code`). A server without
  /// mail autoconfirms addresses: there, accounts sign up and sign in with a password,
  /// and a guardian resets a forgotten one (specs/20, Q48).
  final bool emailCode;

  /// Whether a family exists on the server (`claimed`). Without one, only the address
  /// announced with the setup key may sign up, and the front door leads to the claim
  /// (specs/20 "Claiming the server"). Null for a server from before that migration,
  /// which the app treats as claimed.
  final bool? claimed;

  /// The form the app keeps on the device; [ServerInfo.fromDiscovery] reads it back.
  Map<String, Object?> toJson() => {
    'wuselwall': 1,
    'supabase_url': supabaseUrl.toString(),
    'publishable_key': publishableKey,
    'api_version': apiVersion,
    'min_app_version': minAppVersion,
    'household_creation': householdCreation,
    'sign_in': {'password': true, 'email_code': emailCode},
    'claimed': ?claimed,
    'features': features,
    'server_version': ?serverVersion,
  };

  static final _semver = RegExp(r'^\d+\.\d+\.\d+$');
}
