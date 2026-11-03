import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_providers.dart';

/// "Server: host" on the front door and on every page that takes a code, a password or
/// the setup key, so a person who followed a stranger's link sees where their
/// credentials would go before typing them (security review 2026-11-01, F7). Only in the
/// apps: the web app's own address bar already names its server.
class ServerCaption extends ConsumerWidget {
  const ServerCaption({this.textAlign, super.key});

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(currentServerProvider);
    if (kIsWeb || server == null || server.host.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      context.l10n.serverCaption(displayServerAddress(server)),
      key: const ValueKey('server-caption'),
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: textAlign,
      overflow: TextOverflow.ellipsis,
    );
  }
}
