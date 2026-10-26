import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/features/setup/ui/qr_scan_page.dart';

/// Why a server could not be used, in words a family understands.
enum ServerProblem {
  /// Nothing typed: asks for the address instead of calling it wrong.
  empty,
  invalid,
  unreachable,
  notWuselwall,
  serverTooOld,
  appTooOld,
  linkWithoutServer,
}

String serverProblemText(AppLocalizations l10n, ServerProblem problem) =>
    switch (problem) {
      ServerProblem.empty => l10n.serverEmpty,
      ServerProblem.invalid => l10n.serverInvalid,
      ServerProblem.unreachable => l10n.serverUnreachable,
      ServerProblem.notWuselwall => l10n.serverNotWuselwall,
      ServerProblem.serverTooOld => l10n.serverTooOld,
      ServerProblem.appTooOld => l10n.serverAppTooOld,
      ServerProblem.linkWithoutServer => l10n.serverLinkWithoutServer,
    };

/// The question before the front door of a store build (ADR-018, decision 3; specs/20
/// S0): which server? Type its address, scan its QR code (or a device code that carries
/// it), or look around the demo household first.
class ServerChoicePage extends StatefulWidget {
  const ServerChoicePage({
    required this.onAddress,
    required this.onDemo,
    this.prefill,
    this.problem,
    this.canScan = !kIsWeb,
    super.key,
  });

  /// Connects to what was typed or scanned; returns the problem, or null when the app
  /// moves on to that server.
  final Future<ServerProblem?> Function(String raw) onAddress;
  final VoidCallback onDemo;
  final String? prefill;
  final ServerProblem? problem;
  final bool canScan;

  @override
  State<ServerChoicePage> createState() => _ServerChoicePageState();
}

class _ServerChoicePageState extends State<ServerChoicePage> {
  late final _address = TextEditingController(text: widget.prefill);
  final _addressFocus = FocusNode();
  late ServerProblem? _problem = widget.problem;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  /// Shows a problem on the field and moves focus there, and says it aloud: the red
  /// text alone is not announced to a screen reader (A8).
  void _fail(ServerProblem problem) {
    setState(() {
      _busy = false;
      _problem = problem;
    });
    _addressFocus.requestFocus();
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        serverProblemText(context.l10n, problem),
        Directionality.of(context),
      ),
    );
  }

  Future<void> _connect(String raw) async {
    if (_busy) return;
    if (raw.trim().isEmpty) {
      _fail(ServerProblem.empty);
      return;
    }
    if (parseServerAddress(raw, allowHttp: kDebugMode) == null &&
        parseAppLink(raw) == null &&
        parseInvitation(raw) == null) {
      _fail(ServerProblem.invalid);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final problem = await widget.onAddress(raw);
    if (!mounted) return;
    if (problem != null) {
      _fail(problem);
      return;
    }
    setState(() {
      _busy = false;
      _problem = null;
    });
  }

  Future<void> _scan() async {
    final l10n = context.l10n;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: l10n.serverScan,
          parse: (raw) =>
              parseServerAddress(raw) == null && parseAppLink(raw) == null
              ? null
              : raw,
        ),
      ),
    );
    if (!mounted) return;
    if (raw == null) {
      // Back, or "Code eintippen" where nothing can scan: the code goes into this field,
      // whose helper line shows how (code and server together); an old error would hide it.
      setState(() => _problem = null);
      _addressFocus.requestFocus();
      return;
    }
    final server = parseAppLink(raw)?.server ?? parseServerAddress(raw);
    if (server != null) _address.text = displayServerAddress(server);
    await _connect(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final problem = _problem;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Tokens.space4),
                Text(l10n.serverTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Tokens.space2),
                Text(l10n.serverLead),
                const SizedBox(height: Tokens.space6),
                Semantics(
                  validationResult: problem == null
                      ? SemanticsValidationResult.none
                      : SemanticsValidationResult.invalid,
                  child: TextField(
                    key: const ValueKey('server-address'),
                    controller: _address,
                    focusNode: _addressFocus,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: _connect,
                    decoration: InputDecoration(
                      labelText: l10n.serverAddressLabel,
                      hintText: l10n.serverAddressHint,
                      // An invitation goes here too (SETUP-02): said at the field,
                      // where "Code eintippen" on the scanner leads.
                      helperText: l10n.serverAddressHelper,
                      helperMaxLines: 3,
                      errorText: problem == null
                          ? null
                          : serverProblemText(l10n, problem),
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.space4),
                FilledButton(
                  key: const ValueKey('server-connect'),
                  onPressed: _busy ? null : () => _connect(_address.text),
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.serverConnect),
                ),
                if (widget.canScan) ...[
                  const SizedBox(height: Tokens.space3),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l10n.serverScan),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.space3,
                        ),
                        child: Text(l10n.doorOr),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('server-demo'),
                  onPressed: _busy ? null : widget.onDemo,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l10n.serverDemo),
                ),
                Text(
                  l10n.serverDemoHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Tokens.space6),
                Text(
                  l10n.serverHelp,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the app when the chosen server and this app cannot work together
/// (ADR-018, decision 5).
class ServerIncompatiblePage extends StatelessWidget {
  const ServerIncompatiblePage({
    required this.problem,
    required this.onChooseOther,
    super.key,
  });

  final ServerProblem problem;
  final VoidCallback onChooseOther;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.update,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    l10n.serverIncompatibleTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Tokens.space3),
                  Text(
                    serverProblemText(l10n, problem),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Tokens.space6),
                  OutlinedButton(
                    onPressed: onChooseOther,
                    child: Text(l10n.serverChooseOther),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip above the demo household: what this is, and the way out.
class DemoBanner extends StatelessWidget {
  const DemoBanner({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  l10n.demoBanner,
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
              TextButton(
                key: const ValueKey('demo-exit'),
                onPressed: onExit,
                child: Text(l10n.demoExit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
