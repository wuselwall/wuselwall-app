import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';
import 'package:wuselwall/features/setup/domain/camera_qr_decoder.dart';

/// Lists the cameras of the device. Injected by tests; the default is the camera plugin's.
typedef ListCameras = Future<List<CameraDescription>> Function();

/// Full-screen camera view that pops with the first value [parse] accepts from a QR code.
///
/// The back camera streams frames at about four to five per second; each frame is
/// decoded in a background isolate (pure Dart, no ML Kit or other vendor SDK), and the
/// stream stops as soon as a code is accepted. Without camera access, or without a
/// camera, the page explains why and offers to type the code instead (the caller pops
/// with null). Not covered by automated tests beyond these fallbacks; the decoding it
/// relies on is (see `camera_qr_decoder.dart`).
class QrScanPage extends StatefulWidget {
  const QrScanPage({
    this.title,
    this.parse = parseEnrolmentCode,
    this.listCameras = availableCameras,
    super.key,
  });

  /// The app bar title; defaults to the setup scanner's title.
  final String? title;

  /// Turns decoded QR text into the popped value, or null to keep scanning.
  final String? Function(String raw) parse;

  final ListCameras listCameras;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

enum _ScanPhase { starting, scanning, denied, unavailable, webUnsupported }

class _QrScanPageState extends State<QrScanPage> with WidgetsBindingObserver {
  /// Minimum time between two decoded frames: four to five decodes per second.
  static const _decodeInterval = Duration(milliseconds: 220);

  CameraController? _controller;
  _ScanPhase _phase = _ScanPhase.starting;
  bool _starting = false;
  bool _decoding = false;
  bool _done = false;
  DateTime _lastDecode = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _phase = _ScanPhase.webUnsupported;
    } else {
      unawaited(_start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  // The camera is released while the app is in the background and reopened on return,
  // which also lets a user who granted access in the settings continue without a restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || _done) return;
    if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_starting) unawaited(_start());
    } else {
      unawaited(_releaseCamera());
    }
  }

  Future<void> _start() async {
    _starting = true;
    if (mounted) setState(() => _phase = _ScanPhase.starting);
    try {
      final cameras = await widget.listCameras();
      if (cameras.isEmpty) return _show(_ScanPhase.unavailable);
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        // The decoder reads luminance only: Y on Android, derived from BGRA on iOS.
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted || _done) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_onFrame);
      _show(_ScanPhase.scanning);
    } on CameraException catch (e) {
      await _releaseCamera();
      // The plugin reports a refused permission as CameraAccessDenied (or ...WithoutPrompt
      // and ...Restricted); anything else means the camera could not be opened.
      _show(e.code.startsWith('CameraAccess')
          ? _ScanPhase.denied
          : _ScanPhase.unavailable);
    } on Object {
      // A missing platform implementation or an unexpected failure: no usable camera.
      await _releaseCamera();
      _show(_ScanPhase.unavailable);
    } finally {
      _starting = false;
    }
  }

  void _show(_ScanPhase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  void _onFrame(CameraImage image) {
    if (_done || _decoding) return;
    final now = DateTime.now();
    if (now.difference(_lastDecode) < _decodeInterval) return;
    _lastDecode = now;
    _decoding = true;
    final plane = image.planes.first;
    final frame = ScanFrame(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      bgra: image.format.group == ImageFormatGroup.bgra8888,
    );
    // A failed decode is not an error for a live scanner: the next frame is tried.
    compute(decodeScanFrame, frame)
        .then<void>(_onDecoded, onError: (Object _) {})
        .whenComplete(() => _decoding = false);
  }

  Future<void> _onDecoded(String? raw) async {
    if (raw == null || _done || !mounted) return;
    final value = widget.parse(raw);
    if (value == null) return;
    _done = true;
    await _releaseCamera();
    if (mounted) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.scanTitle)),
      body: switch (_phase) {
        _ScanPhase.scanning when controller != null => Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1 / controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Text(l10n.scanHint, textAlign: TextAlign.center),
            ),
          ],
        ),
        _ScanPhase.denied => _Fallback(
          message: l10n.scanCameraDenied,
          icon: Icons.no_photography_outlined,
        ),
        _ScanPhase.unavailable => _Fallback(
          message: l10n.scanCameraUnavailable,
          icon: Icons.videocam_off_outlined,
        ),
        _ScanPhase.webUnsupported => _Fallback(
          message: l10n.scanWebUnsupported,
          icon: Icons.qr_code_scanner,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Explains why no code can be scanned and offers the typing fallback, which pops null.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: Tokens.space4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: Tokens.space6),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.scanTypeCode),
            ),
          ],
        ),
      ),
    );
  }
}
