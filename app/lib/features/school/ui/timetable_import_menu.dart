import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/school/ui/timetable_paste_sheet.dart';
import 'package:wuselwall/features/school/ui/timetable_scan.dart';

/// The two ways a timetable comes in without typing (specs/24): the assistant's answer
/// pasted as text, or a photo read by the family's own server.
enum TimetableImportWay { text, photo }

/// "Einlesen…" as a toolbar button with the two ways as a menu.
class TimetableImportMenu extends ConsumerWidget {
  const TimetableImportMenu({this.profileId, super.key});

  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(serverSupportsProvider(featureTimetableScan));
    return PopupMenuButton<TimetableImportWay>(
      tooltip: l10n.schoolImportAction,
      onSelected: (way) => unawaited(
        runTimetableImport(context, ref, way, profileId: profileId),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: TimetableImportWay.text,
          child: ListTile(
            leading: const Icon(Icons.content_paste_outlined),
            title: Text(l10n.schoolImportFromText),
          ),
        ),
        PopupMenuItem(
          value: TimetableImportWay.photo,
          child: ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(l10n.schoolImportFromPhoto),
            subtitle: scan ? null : Text(l10n.schoolImportPhotoUnavailable),
            enabled: scan,
          ),
        ),
      ],
      child: TextButton.icon(
        onPressed: null,
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(l10n.schoolImportAction),
        style: TextButton.styleFrom(
          disabledForegroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// The same two ways as a bottom sheet, from a card or a button.
Future<void> showTimetableImportMenu(
  BuildContext context,
  WidgetRef ref, {
  String? profileId,
}) async {
  final way = await showModalBottomSheet<TimetableImportWay>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final scan = ref.read(serverSupportsProvider(featureTimetableScan));
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('import-way-text'),
              leading: const Icon(Icons.content_paste_outlined),
              title: Text(l10n.schoolImportFromText),
              onTap: () =>
                  Navigator.of(sheetContext).pop(TimetableImportWay.text),
            ),
            ListTile(
              key: const ValueKey('import-way-photo'),
              leading: const Icon(Icons.document_scanner_outlined),
              title: Text(l10n.schoolImportFromPhoto),
              // Greyed out, not hidden, where the server cannot read photos: the tap
              // says why and where its operator finds the guide.
              subtitle: scan ? null : Text(l10n.schoolImportPhotoUnavailable),
              enabled: scan,
              onTap: () =>
                  Navigator.of(sheetContext).pop(TimetableImportWay.photo),
            ),
          ],
        ),
      );
    },
  );
  if (way == null || !context.mounted) return;
  await runTimetableImport(context, ref, way, profileId: profileId);
}

Future<void> runTimetableImport(
  BuildContext context,
  WidgetRef ref,
  TimetableImportWay way, {
  String? profileId,
}) async {
  if (way == TimetableImportWay.photo &&
      !ref.read(serverSupportsProvider(featureTimetableScan))) {
    context.showMessage(context.l10n.schoolScanNotConfigured);
    return;
  }
  await _run(context, ref, way, profileId: profileId);
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  TimetableImportWay way, {
  String? profileId,
}) => switch (way) {
  TimetableImportWay.text => showTimetablePasteSheet(
    context,
    ref,
    profileId: profileId,
  ),
  TimetableImportWay.photo => showTimetableScan(
    context,
    ref,
    profileId: profileId,
  ),
};
