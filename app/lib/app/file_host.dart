import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/files/opened_file.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/calendar/domain/ics_import.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// Acts on a calendar file the device opened the app with ([openedFile], specs/05
/// "Sharing one event"): once the device is in its family and on its own screens, the
/// file is read and shown on the import page, where a guardian decides. A device that is
/// not signed in keeps the file until it is; the page itself turns children and shared
/// devices away.
class FileHost extends ConsumerStatefulWidget {
  const FileHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FileHost> createState() => _FileHostState();
}

class _FileHostState extends ConsumerState<FileHost> {
  late final GoRouter _router = ref.read(routerProvider);

  @override
  void initState() {
    super.initState();
    openedFile.addListener(_drain);
    _router.routerDelegate.addListener(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void dispose() {
    openedFile.removeListener(_drain);
    _router.routerDelegate.removeListener(_drain);
    super.dispose();
  }

  void _drain() {
    if (!mounted) return;
    final link = openedFile.value;
    if (link == null) return;
    if (ref.read(sessionStateProvider).value is! Ready) return;
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (path == Routes.splash ||
        path == Routes.firstRun ||
        Routes.isSetup(path)) {
      return;
    }
    openedFile.value = null;
    unawaited(_open(link));
  }

  Future<void> _open(String link) async {
    final bytes = await ref.read(openedFileReaderProvider)(
      link,
      // One more than the import takes, so a larger file is told apart from none.
      maxBytes: icsImportMaxBytes + 1,
    );
    if (!mounted) return;
    if (bytes == null) {
      final context = _router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.showMessage(context.l10n.eventImportUnreadable);
      }
      return;
    }
    unawaited(_router.push(Routes.eventImport, extra: bytes));
  }

  @override
  Widget build(BuildContext context) {
    // The session becoming ready is what a kept file waits for.
    ref.listen(sessionStateProvider, (_, _) => _drain());
    return widget.child;
  }
}
