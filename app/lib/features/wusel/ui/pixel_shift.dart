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
    // The timer runs only while the shift is on, and stops when it is switched off.
    ref.listenManual(
      lighterDayProvider.select((d) => d.pixelShift),
      (_, on) => _arm(on),
      fireImmediately: true,
    );
  }

  void _arm(bool on) {
    if (on && _timer == null) {
      _timer = Timer.periodic(PixelShift.every, (_) {
        if (mounted) setState(() => _step++);
      });
    } else if (!on) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(lighterDayProvider.select((d) => d.pixelShift));
    // Always the same tree, so switching the shift on or off keeps the screen's state.
    return Transform.translate(
      offset: on
          ? PixelShift.offsets[_step % PixelShift.offsets.length]
          : Offset.zero,
      child: widget.child,
    );
  }
}
