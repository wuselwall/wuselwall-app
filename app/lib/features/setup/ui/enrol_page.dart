import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';
import 'package:wuselwall/features/setup/ui/qr_scan_page.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';

/// Enter the one-time code a guardian generated on a trusted device, or scan its QR code.
class EnrolPage extends ConsumerStatefulWidget {
  const EnrolPage({super.key});

  @override
  ConsumerState<EnrolPage> createState() => _EnrolPageState();
}

class _EnrolPageState extends ConsumerState<EnrolPage> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The code scanned together with the server at the server choice: use it at once.
    final pending = ref.read(serverSessionProvider).takePendingEnrolCode();
    if (pending != null) {
      _code.text = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_submit(pending));
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit([String? scanned]) async {
    final code = parseEnrolmentCode(scanned ?? _code.text);
    if (code == null) {
      context.showFailure(const ValidationFailure(code: 'code_invalid'));
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(identityRepositoryProvider).enrolDevice(code);
    if (!mounted) return;
    setState(() => _busy = false);
    result.failureOrNull.let(context.showFailure);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (code != null && mounted) {
      _code.text = code;
      await _submit(code);
    }
  }

  // The camera scanner works on phones and the web; desktop builds have no camera API.
  bool get _canScan =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthFormScaffold(
      title: l10n.enrolTitle,
      children: [
        Text(l10n.enrolBody),
        const SizedBox(height: Tokens.space4),
        if (_canScan) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l10n.scanQr),
          ),
          const SizedBox(height: Tokens.space4),
        ],
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: InputDecoration(labelText: l10n.enrolCodeLabel),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.enrolAction),
        ),
      ],
    );
  }
}
