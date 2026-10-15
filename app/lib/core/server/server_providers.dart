import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/config/config_providers.dart';

/// The origin of the server this app runs on: what invitation links and pairing QR codes
/// name (specs/20, "Choosing the server").
final currentServerProvider = Provider<Uri?>(
  (ref) => Uri.tryParse(ref.watch(appConfigProvider).supabaseUrl),
);
