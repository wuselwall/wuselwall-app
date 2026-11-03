import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The platform's secure storage as the app uses it for secrets: the session, the
/// chosen server and the setup key.
///
/// On iOS the items are readable once the phone has been unlocked after it started, and
/// only on this device: they never travel in an encrypted backup to another phone, which
/// signs in again instead (security review 2026-11-01, F24). The plugin's default, `unlocked`,
/// moves with backups. Items written with the old class are still found: the plugin
/// falls back across every accessibility class when it reads, and the next write
/// replaces the old item with one of the new class. Android ignores these options.
const appSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
