import 'package:flutter/foundation.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

/// What kind of device this phone or browser is, as far as a label needs to know. iPhone
/// and iPad cannot be told apart without a plugin, so every iOS device is an iPhone.
enum DeviceHost { iphone, android, web, computer }

DeviceHost currentDeviceHost() {
  if (kIsWeb) return DeviceHost.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => DeviceHost.iphone,
    TargetPlatform.android => DeviceHost.android,
    _ => DeviceHost.computer,
  };
}

/// "Daniels iPhone" / "Daniel's iPhone": the possessive of a first name, in the language
/// of [localeName]. German adds only an s, except after s, ß, x and z, where it takes an
/// apostrophe (Hans’ iPhone). English adds 's, or only an apostrophe after an s.
String possessiveName(String name, String localeName) {
  final n = name.trim();
  if (n.isEmpty) return n;
  final last = n[n.length - 1].toLowerCase();
  if (localeName.startsWith('de')) {
    return 'sßxz'.contains(last) ? '$n’' : '${n}s';
  }
  return last == 's' ? "$n'" : "$n's";
}

/// The name a new personal device gets, from the member's name and the platform:
/// "Daniels iPhone", "Daniel's iPhone". Without a name it is just the device.
String deviceLabel({
  required AppLocalizations l10n,
  required String ownerName,
  required DeviceHost host,
}) {
  final device = switch (host) {
    DeviceHost.iphone => l10n.householdDeviceIphone,
    DeviceHost.android => l10n.householdDeviceAndroid,
    DeviceHost.web => l10n.householdDeviceBrowser,
    DeviceHost.computer => l10n.householdDeviceComputer,
  };
  final owner = ownerName.trim();
  if (owner.isEmpty) return device;
  return l10n.householdDeviceLabel(
    possessiveName(owner, l10n.localeName),
    device,
  );
}
