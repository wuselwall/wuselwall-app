import 'package:flutter/material.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// Shown instead of the app when the build was made without its configuration, for
/// example without `--dart-define-from-file`. Fails loudly rather than at first request.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.missing, super.key});

  final List<String> missing;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => context.l10n.appTitle,
    supportedLocales: supportedLocales,
    localizationsDelegates: localizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.configMissing(missing.join(', ')),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
