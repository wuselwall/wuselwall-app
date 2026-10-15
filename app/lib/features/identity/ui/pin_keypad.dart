import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// The six dots of a PIN: filled for each digit entered. Digits are never echoed.
class PinDots extends StatelessWidget {
  const PinDots({required this.length, required this.filled, super.key});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            key: ValueKey('pin-dot-$i'),
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? scheme.primary : null,
              border: Border.all(color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

/// The numeric pad for the guardian PIN, sized for the device's register.
class PinKeypad extends ConsumerWidget {
  const PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final touch = ref.watch(uiRegisterProvider).touchTarget;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: touch + 12,
                    height: touch,
                    child: key.isEmpty
                        ? null
                        : key == '<'
                        ? IconButton(
                            tooltip: l10n.delete,
                            onPressed: enabled ? onBackspace : null,
                            icon: const Icon(Icons.backspace_outlined),
                          )
                        : OutlinedButton(
                            onPressed: enabled ? () => onDigit(key) : null,
                            child: Text(key),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
