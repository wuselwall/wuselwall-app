import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Moves the whole screen by up to 2 px every 10 minutes when `device.pixel_shift`
/// says so (specs/26 "Protecting the wall"). The operating systems protect their own
/// status bars and clocks from burn-in, not a full-screen app that shows the same
/// header for months. On an LCD it costs nothing, so the wall has it on by default.
class PixelShift extends ConsumerStatefulWidget {
  const PixelShift({required this.child, super.key});

  final Widget child;

  /// A small circuit, so no pixel stays lit by the same edge for long.
  static const offsets = [
    Offset.zero,
    Offset(1, 0),
    Offset(2, 1),
    Offset(1, 2),
    Offset(0, 1),
    Offset(-1, 0),
    Offset(-2, -1),
    Offset(-1, -2),
    Offset(0, -1),
  ];

  static const every = Duration(minutes: 10);

  @override
  ConsumerState<PixelShift> createState() => _PixelShiftState();
}

class _PixelShiftState extends ConsumerState<PixelShift> {
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(PixelShift.every, (_) {
      if (mounted) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(lighterDayProvider).pixelShift) return widget.child;
    return Transform.translate(
      offset: PixelShift.offsets[_step % PixelShift.offsets.length],
      child: widget.child,
    );
  }
}
