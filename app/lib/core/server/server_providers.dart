import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wuselwall/core/config/config_providers.dart';

/// The origin of the server this app runs on: what invitation links and pairing QR codes
/// name (specs/20, "Choosing the server").
final currentServerProvider = Provider<Uri?>(
  (ref) => Uri.tryParse(ref.watch(appConfigProvider).supabaseUrl),
);

/// The server can read a timetable from a photo or a PDF: its OCR service is set up
/// (specs/24 "Scanning"). Announced by servers from 0.3.0 on.
const featureTimetableScan = 'timetable-scan';

/// Whether the server this app runs on announces [feature] in its discovery document.
/// A build with a compiled-in server (development, the demo) has no document and is
/// taken to support everything.
final serverSupportsProvider = Provider.family<bool, String>((ref, feature) {
  final server = ref.watch(appConfigProvider).server;
  return server == null || server.features.contains(feature);
});

/// This app's version ("1.1.0"), for the settings' versions line. Overridden in tests and
/// in the demo.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);
