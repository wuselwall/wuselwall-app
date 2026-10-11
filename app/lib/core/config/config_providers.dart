import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/config/app_config.dart';

/// Overridden in `main()` with the validated build configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
