import 'package:flutter/material.dart';

/// A label with a − value + stepper, for servings and guests. Both ends are clamped to
/// [min] and [max].
class CountStepper extends StatelessWidget {
  const CountStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      ),
      IconButton(
        icon: const Icon(Icons.remove),
        onPressed: value > min ? () => onChanged(value - 1) : null,
      ),
      SizedBox(
        width: 40,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: value < max ? () => onChanged(value + 1) : null,
      ),
    ],
  );
}
