import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';

/// A guardian signed in on a phone the household has not seen: name it, and it becomes
/// that guardian's personal device — one row per phone, revocable on its own.
class RegisterDevicePage extends ConsumerStatefulWidget {
  const RegisterDevicePage({required this.guardianName, super.key});

  final String guardianName;

  @override
  ConsumerState<RegisterDevicePage> createState() => _RegisterDevicePageState();
}

class _RegisterDevicePageState extends ConsumerState<RegisterDevicePage> {
  final _label = TextEditingController();
  bool _busy = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      _label.text = context.l10n.registerDefaultLabel(widget.guardianName);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .registerPersonalDevice(_label.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => ref.invalidate(sessionStateProvider),
      err: context.showFailure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                Text(l10n.registerBody(widget.guardianName)),
                const SizedBox(height: Tokens.space4),
                TextField(
                  controller: _label,
                  decoration: InputDecoration(labelText: l10n.deviceLabel),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Tokens.space4),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(l10n.registerAction),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(identityRepositoryProvider).signOut(),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
