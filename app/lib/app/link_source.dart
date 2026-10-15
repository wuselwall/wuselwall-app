import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// The links the app is opened with, as text: the one that started it and the ones that
/// arrive while it runs (universal links on iOS, App Links on Android). The web app is
/// served by its server and is never opened with a link.
Stream<String>? openedLinks() => kIsWeb ? null : AppLinks().stringLinkStream;
