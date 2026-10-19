import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wuselwall/app/bootstrap.dart';
import 'package:wuselwall/app/config_error_app.dart';
import 'package:wuselwall/app/licenses.dart';
import 'package:wuselwall/app/link_source.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/server/setup_link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logError(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  final config = AppConfig.fromEnvironment();
  final missing = config.validate();
  if (missing.isNotEmpty) {
    runApp(ConfigErrorApp(missing: missing));
    return;
  }

  final initialSetup = kIsWeb ? parseSetupLink(Uri.base.toString()) : null;
  // Remove installer capabilities from browser history before the router starts.
  // The fragment was never sent to the web server or the discovery endpoint.
  if (kIsWeb && Uri.base.fragment.startsWith('setup=')) {
    await SystemNavigator.routeInformationUpdated(
      uri: Uri(path: '/'),
      replace: true,
    );
  }

  // Which server: the build's, the one chosen before, or the question (ADR-018).
  runApp(
    Bootstrap(
      build: config,
      initialSetup: initialSetup,
      links: openedLinks(),
      webOrigin: kIsWeb
          ? Uri(
              scheme: Uri.base.scheme,
              host: Uri.base.host,
              port: Uri.base.hasPort ? Uri.base.port : null,
            )
          : null,
    ),
  );
}
