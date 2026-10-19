import 'package:flutter/services.dart';

/// Shows typed codes like the code on the new device, while allowing pasted links.
class PairingCodeInputFormatter extends TextInputFormatter {
  static final _codeInput = RegExp(r'^[a-zA-Z0-9\s-]*$');
  static final _separators = RegExp(r'[\s-]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed ||
        !_codeInput.hasMatch(newValue.text)) {
      return newValue;
    }

    final code = newValue.text.replaceAll(_separators, '').toUpperCase();
    final text = code.length > 4
        ? '${code.substring(0, 4)}-${code.substring(4)}'
        : code;

    int offset(int position) {
      if (position < 0) return position;
      final symbols = newValue.text
          .substring(0, position)
          .replaceAll(_separators, '')
          .length;
      return symbols > 4 ? symbols + 1 : symbols;
    }

    return newValue.copyWith(
      text: text,
      selection: newValue.selection.copyWith(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}
