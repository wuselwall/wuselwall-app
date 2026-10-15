import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// One camera frame as the camera plugin delivers it, before any conversion.
///
/// Android streams YUV420, where [bytes] is the Y (luminance) plane. iOS streams BGRA,
/// where [bytes] holds four bytes per pixel. [bytesPerRow] is the row stride, which can
/// be wider than [width] (padding), so it is never assumed to equal the width.
class ScanFrame {
  const ScanFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.bgra,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool bgra;
}

/// Decodes the first QR code in [frame], or returns null when there is none.
///
/// Pure Dart and free of Flutter imports, so the page can run it with `compute`
/// (off the UI isolate) and tests can run it directly. A frame that cannot be decoded
/// (no code, blur, malformed data, a size the binarizer rejects) is not an error for a
/// live scanner: it returns null and the next frame is tried.
String? decodeScanFrame(ScanFrame frame) {
  final source = _luminanceSource(frame);
  if (source == null) return null;
  try {
    return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
  } on Exception {
    return null;
  }
}

/// A luminance source over [frame]. Only the Y plane is read for YUV420 (no copy: the
/// view shares the plugin's buffer). BGRA is reduced to luminance first.
LuminanceSource? _luminanceSource(ScanFrame frame) {
  final width = frame.width;
  final height = frame.height;
  if (width <= 0 || height <= 0) return null;
  if (frame.bgra) {
    if (frame.bytesPerRow < width * 4 ||
        frame.bytes.length < frame.bytesPerRow * height) {
      return null;
    }
    return _bgraLuminance(frame);
  }
  if (frame.bytesPerRow < width ||
      frame.bytes.length < frame.bytesPerRow * height) {
    return null;
  }
  final bytes = frame.bytes;
  return _LuminancePlane(
    bytes.buffer.asInt8List(bytes.offsetInBytes, bytes.lengthInBytes),
    frame.bytesPerRow,
    width,
    height,
  );
}

/// Luminance of a BGRA frame, using the ITU-R BT.601 weights (as the Y of YUV).
/// The result is a packed `width` x `height` buffer.
LuminanceSource _bgraLuminance(ScanFrame frame) {
  final width = frame.width;
  final height = frame.height;
  final src = frame.bytes;
  final out = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    var i = y * frame.bytesPerRow;
    var o = y * width;
    for (var x = 0; x < width; x++, i += 4, o++) {
      final b = src[i];
      final g = src[i + 1];
      final r = src[i + 2];
      out[o] = (r * 77 + g * 150 + b * 29) >> 8;
    }
  }
  return _LuminancePlane(out.buffer.asInt8List(), width, width, height);
}

/// A packed or padded plane of 8-bit luminance. [stride] is the distance between rows
/// in bytes. zxing masks each value with 0xff, so the signed view of the bytes is fine.
class _LuminancePlane extends LuminanceSource {
  _LuminancePlane(this._data, this._stride, int width, int height)
    : super(width, height);

  final Int8List _data;
  final int _stride;

  @override
  Int8List getRow(int y, Int8List? row) {
    final out = (row == null || row.length < width) ? Int8List(width) : row;
    out.setRange(0, width, _data, y * _stride);
    return out;
  }

  @override
  Int8List getMatrix() {
    if (_stride == width) return Int8List.sublistView(_data, 0, width * height);
    final matrix = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      matrix.setRange(y * width, (y + 1) * width, _data, y * _stride);
    }
    return matrix;
  }
}
