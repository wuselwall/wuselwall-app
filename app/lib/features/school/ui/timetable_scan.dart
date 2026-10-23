import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/scan_repository.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';

/// Picks a picture, from the camera or the gallery, through [ImagePicker]. The picker
/// resizes and re-encodes, so an iPhone's HEIC arrives as a JPEG. Overridden in tests and
/// in the demo, which has no camera.
final imagePickerProvider = Provider<Future<XFile?> Function(ImageSource)>(
  (ref) =>
      (source) => ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      ),
);

/// A file the school handed out: the PDF, or a picture kept outside the gallery. The
/// server reads a PDF's text layer directly, so this is the most exact way in. Overridden
/// in tests and in the demo.
final filePickerProvider = Provider<Future<PickedFile?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final file = files.firstOrNull;
    if (file == null) return null;
    return PickedFile(bytes: await file.readAsBytes(), name: file.name);
  },
);

/// What the file picker gives: the bytes and the name, for the type.
class PickedFile {
  const PickedFile({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// The type the server is told, from the file's name (and the picker's own word, when it
/// has one). A photo is a JPEG.
String mimeOf(String name, {String? reported}) {
  final lower = name.toLowerCase();
  if (reported == 'image/png' || lower.endsWith('.png')) return 'image/png';
  if (reported == 'image/webp' || lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}

enum _ScanSource { camera, gallery, file }

/// Scans a timetable on the family's own server (specs/24 "Scanning"): the parent takes
/// or picks the picture, or picks the school's PDF; the server reads it; the preview shows
/// the result. A server without OCR says so, with a pointer to its guide.
Future<void> showTimetableScan(
  BuildContext context,
  WidgetRef ref, {
  String? profileId,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final source = await showModalBottomSheet<_ScanSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space4,
                vertical: Tokens.space2,
              ),
              child: Text(l10n.schoolScanIntro),
            ),
            ListTile(
              key: const ValueKey('scan-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.schoolScanCamera),
              onTap: () => Navigator.of(sheetContext).pop(_ScanSource.camera),
            ),
            ListTile(
              key: const ValueKey('scan-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.schoolScanPick),
              onTap: () => Navigator.of(sheetContext).pop(_ScanSource.gallery),
            ),
            ListTile(
              key: const ValueKey('scan-file'),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.schoolScanFile),
              onTap: () => Navigator.of(sheetContext).pop(_ScanSource.file),
            ),
          ],
        ),
      );
    },
  );
  if (source == null || !context.mounted) return;

  final Uint8List bytes;
  final String mime;
  if (source == _ScanSource.file) {
    final picked = await ref.read(filePickerProvider)();
    if (picked == null || !context.mounted) return;
    bytes = picked.bytes;
    mime = mimeOf(picked.name);
  } else {
    final file = await ref.read(imagePickerProvider)(
      source == _ScanSource.camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null || !context.mounted) return;
    bytes = await file.readAsBytes();
    if (!context.mounted) return;
    mime = mimeOf(file.name, reported: file.mimeType);
  }

  // The family's language and its subjects steer the server's reading (specs/24).
  final subjects = ref.read(schoolDataProvider).value?.subjects ?? const [];
  final result = await _busy(
    context,
    ref
        .read(scanRepositoryProvider)
        .scan(
          image: bytes,
          mime: mime,
          languages: [Localizations.localeOf(context).languageCode],
          subjects: [
            for (final s in subjects) ...[s.shortName, s.name],
          ],
        ),
  );
  if (!context.mounted) return;
  switch (result) {
    case Err(:final failure):
      context.showFailure(failure);
    case Ok(:final value):
      unawaited(
        context.push(
          Routes.timetableImport,
          extra: TimetableImportArgs(
            import: value.import,
            profileId: profileId,
            unplaced: value.unplaced,
          ),
        ),
      );
  }
}

/// Shows "the sheet is being read" while [work] runs.
Future<T> _busy<T>(BuildContext context, Future<T> work) async {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: Tokens.space4),
            Expanded(child: Text(dialogContext.l10n.schoolScanBusy)),
          ],
        ),
      ),
    ),
  );
  try {
    return await work;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
