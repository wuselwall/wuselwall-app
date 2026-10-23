import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';

/// The payload's shape, for the assistant's instructions. English like every contract;
/// the sentences around it are in the family's language ([AppLocalizations.schoolImportPrompt]).
const timetableImportFormatSpec = '''
{
  "format": "wuselwall-timetable/1",
  "member": "<child's first name>",
  "school": "<school name, if on the sheet>",
  "class": "<class, e.g. 3b, if on the sheet>",
  "week_cycle": "weekly" | "ab",
  "periods": [{"index": 1, "starts": "08:00", "ends": "08:45"}],
  "lessons": [
    {"day": "Mo", "period": 1, "subject": "Ma", "name": "Mathematik", "teacher": "", "room": "", "week": "a" | "b" | null}
  ],
  "care": [{"title": "Hort", "days": ["Mo", "Di"], "starts": "13:30", "ends": "15:30"}]
}''';

/// Opens the paste sheet for [profileId]. The parent pastes an assistant's answer; a
/// readable payload opens the import preview.
Future<void> showTimetablePasteSheet(
  BuildContext context,
  WidgetRef ref, {
  String? profileId,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TimetablePasteSheet(profileId: profileId),
  );
}

class TimetablePasteSheet extends StatefulWidget {
  const TimetablePasteSheet({this.profileId, super.key});

  final String? profileId;

  @override
  State<TimetablePasteSheet> createState() => _TimetablePasteSheetState();
}

class _TimetablePasteSheetState extends State<TimetablePasteSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    final l10n = context.l10n;
    await Clipboard.setData(
      ClipboardData(
        text: '${l10n.schoolImportPrompt}\n\n$timetableImportFormatSpec',
      ),
    );
    if (mounted) context.showMessage(l10n.schoolImportPromptCopied);
  }

  void _read() {
    final l10n = context.l10n;
    final TimetableImport import;
    try {
      import = parseTimetableImport(_text.text);
    } on ImportParseException catch (e) {
      setState(
        () => _error = switch (e.error) {
          ImportError.notJson => l10n.schoolImportErrNotJson,
          ImportError.noLessons => l10n.schoolImportErrNoLessons,
          ImportError.tooMany => l10n.schoolImportErrTooMany,
          ImportError.badLesson => l10n.schoolImportErrBadLesson,
          ImportError.badDay => l10n.schoolImportErrBadDay(e.detail ?? ''),
          ImportError.badTime => l10n.schoolImportErrBadTime(e.detail ?? ''),
        },
      );
      return;
    }
    Navigator.of(context).pop();
    unawaited(
      context.push(
        Routes.timetableImport,
        extra: TimetableImportArgs(import: import, profileId: widget.profileId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.space4,
        right: Tokens.space4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.schoolImportPasteTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: Tokens.space2),
          Text(l10n.schoolImportPasteIntro),
          const SizedBox(height: Tokens.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _copyPrompt,
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.schoolImportCopyPrompt),
            ),
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            key: const ValueKey('import-paste'),
            controller: _text,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: l10n.schoolImportPasteHint,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: Tokens.space3),
          FilledButton(
            key: const ValueKey('import-read'),
            onPressed: _text.text.trim().isEmpty && _error == null
                ? null
                : _read,
            child: Text(l10n.schoolImportRead),
          ),
        ],
      ),
    );
  }
}
