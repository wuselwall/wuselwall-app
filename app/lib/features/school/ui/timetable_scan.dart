import 'dart:async';

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
import 'package:wuselwall/features/school/data/scan_repository.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';

/// Picks a picture, from the camera or the gallery, through [ImagePicker]. Overridden in
/// tests and in the demo, which has no camera.
final imagePickerProvider = Provider<Future<XFile?> Function(ImageSource)>(
  (ref) =>
      (source) => ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      ),
);

/// Scans a photographed timetable on the family's own server (specs/24 "Scanning"):
/// the parent picks or takes the picture, the server reads it, the preview shows the
/// result. A server without OCR says so, with a pointer to its guide.
Future<void> showTimetableScan(
  BuildContext context,
  WidgetRef ref, {
  String? profileId,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final source = await showModalBottomSheet<ImageSource>(
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
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('scan-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.schoolScanPick),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
  if (source == null || !context.mounted) return;
  final file = await ref.read(imagePickerProvider)(source);
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  final mime = switch (file.mimeType ?? '') {
    'image/png' => 'image/png',
    'image/webp' => 'image/webp',
    _ =>
      file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : file.name.toLowerCase().endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg',
  };

  final result = await _busy(
    context,
    ref.read(scanRepositoryProvider).scan(image: bytes, mime: mime),
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
