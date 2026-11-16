import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handing a link, a phone number or an address of a trip entry to the phone's own apps
/// (specs/30 "Options and the plan"): the browser, the dialler, the maps app. The app itself
/// contacts none of them, and nothing here goes through the family's server.
///
/// Each returns false when nothing could be opened, so the page can say so.

Future<bool> openTripLink(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return false;
  }
  return _launch(uri);
}

Future<bool> callTripPhone(String phone) async {
  final digits = phone.replaceAll(RegExp('[^0-9+]'), '');
  if (digits.isEmpty) return false;
  return _launch(Uri(scheme: 'tel', path: digits));
}

/// Opens the maps app at an address, or at coordinates when there is no address.
Future<bool> openTripPlace({String? address, double? lat, double? lon}) async {
  final text = address?.trim() ?? '';
  final hasPoint = lat != null && lon != null;
  if (text.isEmpty && !hasPoint) return false;
  final query = text.isNotEmpty ? text : '$lat,$lon';
  return _launch(
    tripPlaceUri(query, platform: defaultTargetPlatform, web: kIsWeb),
  );
}

/// The address a platform's maps app answers to. Android has the `geo:` scheme; Apple's maps
/// open from their own https address; a browser gets OpenStreetMap's search page.
@visibleForTesting
Uri tripPlaceUri(
  String query, {
  required TargetPlatform platform,
  required bool web,
}) {
  if (!web && platform == TargetPlatform.android) {
    return Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(query)}');
  }
  if (!web &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)) {
    return Uri.https('maps.apple.com', '/', {'q': query});
  }
  return Uri.https('www.openstreetmap.org', '/search', {'query': query});
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
