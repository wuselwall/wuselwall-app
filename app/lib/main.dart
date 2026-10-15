import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wuselwall/app/bootstrap.dart';
import 'package:wuselwall/app/config_error_app.dart';
import 'package:wuselwall/app/licenses.dart';
import 'package:wuselwall/app/link_source.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/logging/log.dart';

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

  // Which server: the build's, the one chosen before, or the question (ADR-018).
  runApp(
    Bootstrap(
      build: config,
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
