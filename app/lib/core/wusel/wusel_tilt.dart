import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// How far the phone or tablet in the hand is tilted sideways, for Wusel to lean and
/// slide downhill (specs/25 "Wusel on the move"): −1 with the left side down, 1 with
/// the right side down, relative to the screen as the person sees it.
///
/// The accelerometer is listened to only while someone listens here and the app is in
/// the foreground; the readings are smoothed and a change of less than about 4° is
/// not passed on, so a tablet lying still wakes nothing. Native iOS and Android only:
/// [available] is switched on by `main` there, and stays off on the web, on the wall
/// and in tests (where there is no sensor plugin).
class WuselTilt extends ValueNotifier<double?> with WidgetsBindingObserver {
  WuselTilt._() : super(null);

  /// The one tilt source of the app.
  static final instance = WuselTilt._();

  /// Whether the platform has the sensor. Set once at start-up.
  static bool available = false;

  /// Where screen-down points on the device, learnt from gravity whenever the device
  /// is clearly held upright; the OS turns the screen by the same rule.
  ScreenDown _down = ScreenDown.portrait;
  double _smooth = 0;
  StreamSubscription<AccelerometerEvent>? _events;
  bool _observing = false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _follow();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _follow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _follow();

  void _follow() {
    final want =
        available &&
        hasListeners &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden;
    if (hasListeners && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } else if (!hasListeners && _observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    if (want && _events == null) {
      _events = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(_onEvent, onError: (Object _) => _stop(), cancelOnError: true);
    } else if (!want && _events != null) {
      _stop();
    }
  }

  void _stop() {
    unawaited(_events?.cancel());
    _events = null;
    value = null;
  }

  void _onEvent(AccelerometerEvent e) {
    final next = tiltFrom(e.x, e.y, previous: _down);
    _down = next.down;
    // A low-pass filter: the hand's tremor is not a tilt.
    _smooth += (next.tilt - _smooth) * 0.25;
    final current = value;
    if (current == null || (_smooth - current).abs() >= 0.07) {
      value = _smooth;
    }
  }
}

/// Which device edge is the bottom of the screen.
enum ScreenDown { portrait, portraitFlipped, landscapeLeft, landscapeRight }

/// The sideways tilt of the screen from the accelerometer's [x] and [y] (in m/s², the
/// reaction to gravity, device axes: x to the right, y to the top of the device in its
/// natural orientation). The screen's bottom follows gravity while the device is held
/// clearly upright, as the OS does when it rotates; lying almost flat it keeps
/// [previous].
@visibleForTesting
({double tilt, ScreenDown down}) tiltFrom(
  double x,
  double y, {
  ScreenDown previous = ScreenDown.portrait,
}) {
  const g = 9.81;
  // Gravity on the screen's plane, device axes, pointing down.
  final gx = -x / g;
  final gy = -y / g;
  var down = previous;
  if (gx * gx + gy * gy > 0.36) {
    down = gx.abs() > gy.abs()
        ? (gx > 0 ? ScreenDown.landscapeRight : ScreenDown.landscapeLeft)
        : (gy < 0 ? ScreenDown.portrait : ScreenDown.portraitFlipped);
  }
  // Sideways on the screen: positive when the screen's right side is lower.
  final double sideways = switch (down) {
    ScreenDown.portrait => gx,
    ScreenDown.portraitFlipped => -gx,
    // Turned clockwise, the device's top points to the screen's right.
    ScreenDown.landscapeRight => gy,
    ScreenDown.landscapeLeft => -gy,
  };
  return (tilt: sideways.clamp(-1.0, 1.0), down: down);
}
