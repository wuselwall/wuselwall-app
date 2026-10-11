import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/config_error_app.dart';
import 'package:wuselwall/app/licenses.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/supabase/supabase_bootstrap.dart';

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

  await initSupabase(config);

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const WuselWallApp(),
    ),
  );
}
