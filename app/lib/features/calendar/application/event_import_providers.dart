import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/calendar/application/event_share_providers.dart';

/// Whether this device may take an event from a file (specs/05 "Sharing one event"): a
/// guardian on their own personal device, as for sending one. The server checks again
/// where it knows the import (`api.event_import`).
final canImportEventProvider = Provider<bool>(
  (ref) => ref.watch(canShareEventProvider),
);

/// Whether the server remembers a received event's origin. Without it the event is
/// added as a new one each time.
final eventImportSupportedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(serverSupportsProvider(featureEventImport)),
);

/// Lets the person choose a calendar file; null when they chose none. Overridden in
/// tests and in the demo.
final calendarFilePickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ics', 'ical'],
    );
    final file = files.firstOrNull;
    return file?.readAsBytes();
  },
);
