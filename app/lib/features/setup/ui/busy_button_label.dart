import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';

/// A button's label while its action runs: a small spinner and what is happening
/// ("Familie wird angelegt …"), so a disabled form never looks frozen.
class BusyButtonLabel extends StatelessWidget {
  const BusyButtonLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: Tokens.space2,
    runSpacing: Tokens.space1,
    children: [
      const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      Text(label),
    ],
  );
}
