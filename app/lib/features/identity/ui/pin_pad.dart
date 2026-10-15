import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/pin_keypad.dart';

/// Numeric pad for the 6-digit guardian PIN. The digits are never echoed — only dots —
/// because the pad sits on a wall display in a busy kitchen (specs/08).
class PinPadDialog extends ConsumerStatefulWidget {
  const PinPadDialog({required this.guardian, super.key});

  final Member guardian;

  @override
  ConsumerState<PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends ConsumerState<PinPadDialog> {
  static const _length = 6;
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _press(String digit) async {
    if (_busy || _pin.length >= _length) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _length) await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .verifyPin(profileId: widget.guardian.id, pin: _pin);
    if (!mounted) return;
    final l10n = context.l10n;

    result.when(
      ok: (pin) {
        switch (pin) {
          case PinVerified(:final verifiedUntil):
            ref.read(guardianVerifiedProvider.notifier).set(verifiedUntil);
            Navigator.pop(context, true);
            return;
          case PinWrong(:final attemptsLeft):
            _error = l10n.pinWrong(attemptsLeft);
          case PinBackoff():
            _error = l10n.pinBackoff;
          case PinLocked():
            _error = l10n.pinLocked;
        }
        setState(() {
          _pin = '';
          _busy = false;
        });
      },
      err: (failure) {
        setState(() {
          _pin = '';
          _busy = false;
        });
        context.showFailure(failure);
      },
    );
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.pinTitle),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.pinPrompt(widget.guardian.displayName)),
            const SizedBox(height: Tokens.space4),
            PinDots(length: _length, filled: _pin.length),
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  _error ?? '',
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            PinKeypad(
              enabled: !_busy,
              onDigit: _press,
              onBackspace: _backspace,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
