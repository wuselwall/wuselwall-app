import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// One text field in a dialog: a name, a label. Resolves to the trimmed text, or null
/// when cancelled or left empty. The dialog owns its controller, so the field can still
/// draw while the dialog animates away.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
  int maxLength = 40,
  String? confirm,
  Key? fieldKey,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    label: label,
    initial: initial,
    maxLength: maxLength,
    confirm: confirm,
    fieldKey: fieldKey,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.label,
    required this.initial,
    required this.maxLength,
    required this.confirm,
    required this.fieldKey,
  });

  final String title;
  final String label;
  final String? initial;
  final int maxLength;
  final String? confirm;
  final Key? fieldKey;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirm ?? l10n.save),
        ),
      ],
    );
  }
}
