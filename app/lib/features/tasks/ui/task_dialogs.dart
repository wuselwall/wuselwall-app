import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// A short free-text note, for a decline. Null when cancelled; an empty string when the
/// guardian left it blank (the server stores no note then).
Future<String?> askTaskNote(BuildContext context, {required String title}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(title: title),
    );

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title});

  final String title;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _note,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(labelText: l10n.tasksNoteOptional),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(l10n.tasksDecline),
        ),
      ],
    );
  }
}
