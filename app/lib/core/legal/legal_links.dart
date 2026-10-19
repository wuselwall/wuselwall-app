import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// The privacy policy on the public website (ADR-017): German at `/datenschutz`, English at
/// `/en/privacy`. The app has no server of its own to host it (ADR-018).
Uri privacyPolicyUri(Locale locale) =>
    Uri.https('wuselwall.app', switch (locale.languageCode) {
      'en' || 'fr' || 'es' => '/en/privacy',
      _ => '/datenschutz',
    });

/// Opens the privacy policy in the browser. Returns false when the platform refused.
Future<bool> openPrivacyPolicy(Locale locale) =>
    launchUrl(privacyPolicyUri(locale), mode: LaunchMode.externalApplication);
