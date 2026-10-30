import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel_look.dart';
import 'package:wuselwall/core/wusel/wusel_painter.dart';
import 'package:wuselwall/core/wusel/wusel_pose.dart';
import 'package:wuselwall/core/wusel/wusel_rig.dart';

export 'package:wuselwall/core/wusel/wusel_look.dart' show WuselOutfit;
export 'package:wuselwall/core/wusel/wusel_painter.dart' show WuselColors;
export 'package:wuselwall/core/wusel/wusel_pose.dart';

/// Wusel, the family's companion (specs/25), in one [pose].
///
/// The pose moves for a moment and then rests: the widget draws frames only while
/// something is happening (the pose's own motion, a blink, the springs of the
/// [WuselRig] settling), so a wall that shows Wusel all day is not redrawing it all
/// day. A sleeping Wusel breathes all night, but at [sleepFrame] intervals from a
/// timer rather than on every frame, and not at all while its route is hidden. Under
/// reduced motion ([motionAllowed]) it shows the pose's still look and never ticks.
///
/// [gazeAt], [glancing] and [tilt] wake it from outside: the finger it looks at, the
/// afterglow in which it glances about and hops on the spot, and the tilt of the
/// tablet in the hand (specs/25 "Wusel on the move"). Each wakes the ticker only for
/// as long as the springs need to follow.
///
/// The drawing is decoration and is hidden from screen readers; whatever Wusel says
/// belongs in the screen's own text (see `WuselSays`).
class Wusel extends StatefulWidget {
  const Wusel({
    required this.colors,
    this.pose = WuselPose.idle,
    this.size = 96,
    this.outfit = WuselOutfit.none,
    this.frontTuft,
    this.moment,
    this.onTap,
    this.still = false,
    this.restAfter,
    this.gazeAt,
    this.glancing,
    this.tilt,
    super.key,
  });

  final WuselColors colors;
  final WuselPose pose;

  /// The edge of the square Wusel is drawn in. Below 32 Wusel is not drawn at all.
  final double size;
  final WuselOutfit outfit;
  final int? frontTuft;

  /// Change this to play the same pose again, e.g. a second cheer.
  final Object? moment;

  /// A tap gives a small reaction that depends on where the finger lands (specs/25
  /// "Wusel on the move", tickles); null for none.
  final VoidCallback? onTap;

  /// Holds the pose's still look, as under reduced motion: a quiet Wusel, a picker.
  final bool still;

  /// Stops the idle blink this long after the last moment (a new pose, [moment] or a
  /// tap), until the next one: the wall rests after 60 s (specs/25 "Power on the
  /// wall"). Null blinks for as long as Wusel is shown.
  final Duration? restAfter;

  /// A point in global coordinates for the eyes to follow (the finger), or null.
  final ValueListenable<Offset?>? gazeAt;

  /// While true, Wusel is in its afterglow: it glances about and hops on the spot now
  /// and then.
  final ValueListenable<bool>? glancing;

  /// The tablet's sideways tilt, −1 (left side down) to 1, or null when unknown.
  final ValueListenable<double?>? tilt;

  /// Below this Wusel stops reading as a character (specs/25 "The drawing").
  static const minSize = 32.0;

  /// How often a sleeping Wusel draws its breath: five frames a second, enough for a
  /// 4.5 s breath and the drifting "z" (specs/25 "Power on the wall").
  static const sleepFrame = Duration(milliseconds: 200);

  @override
  State<Wusel> createState() => _WuselState();
}

class _WuselState extends State<Wusel> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _random = math.Random();
  final _rig = WuselRig();

  /// What is moving right now; null while resting.
  _Run? _run;
  Duration _now = Duration.zero;
  Duration _lastTick = Duration.zero;
  WuselLook? _blendFrom;
  Duration _blendStart = Duration.zero;
  late WuselLook _look = widget.pose.still;

  /// The body's height in the last frame, for the speed the rig follows.
  double? _lastLift;

  /// A run ended and the rig is still settling: once it has, Wusel rests as after any
  /// run (a blink scheduled, or back to sleep).
  bool _restPending = false;

  Timer? _blinkTimer;
  _Tickle _tickle = _Tickle.giggle;
  final _taps = <Duration>[];

  /// Draws the sleeping look at [Wusel.sleepFrame] intervals while [WuselPose.sleep]
  /// rests; [_sleepClock] is how long Wusel has slept, counted in those frames.
  Timer? _sleepTimer;
  Duration _sleepClock = Duration.zero;

  /// Runs from the last moment until [Wusel.restAfter]; once it has fired, no blink is
  /// scheduled until the next moment.
  Timer? _restTimer;
  bool _resting = false;

  /// The afterglow's glances and hops on the spot.
  Timer? _glanceTimer;
  Timer? _hopTimer;
  Offset _glance = Offset.zero;

  /// The tilt last followed, so a tablet held almost still does not wake Wusel.
  double _followedTilt = 0;

  static const _blend = Duration(milliseconds: 250);
  static const _blinkLength = Duration(milliseconds: 180);
  static const _reactionLength = Duration(milliseconds: 600);
  static const _wriggleLength = Duration(milliseconds: 1000);
  static const _hopLength = Duration(milliseconds: 520);

  /// Below this change (about 4°) a tilt does not wake Wusel.
  static const _tiltStep = 0.07;

  /// Null until the first build has asked [motionAllowed].
  bool? _moving;

  @override
  void initState() {
    super.initState();
    _listen(widget);
  }

  void _listen(Wusel w) {
    w.gazeAt?.addListener(_wake);
    w.glancing?.addListener(_onGlancing);
  }

  void _unlisten(Wusel w) {
    w.gazeAt?.removeListener(_wake);
    w.glancing?.removeListener(_onGlancing);
    _followTilt(null);
  }

  /// The tilt source listened to; only while this Wusel can be seen, so a route on
  /// top of it switches the sensor off (specs/25 "On the move").
  ValueListenable<double?>? _tiltHeard;

  void _followTilt(ValueListenable<double?>? source) {
    if (source == _tiltHeard) return;
    _tiltHeard?.removeListener(_onTilt);
    _tiltHeard = source;
    source?.addListener(_onTilt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
    _followVisibility();
    _followTilt(_visible ? widget.tilt : null);
  }

  /// A sleeping Wusel on a hidden route stops breathing until it is seen again.
  void _followVisibility() {
    final visible = _visible;
    if (!visible && _sleepTimer != null) {
      _sleepTimer!.cancel();
      _sleepTimer = null;
    } else if (visible &&
        _sleepTimer == null &&
        _moving == true &&
        _run == null &&
        widget.pose == WuselPose.sleep) {
      _sleepTimer = Timer.periodic(Wusel.sleepFrame, _onSleepFrame);
    }
  }

  void _updateMotion() {
    final moving = !widget.still && motionAllowed(context);
    if (moving == _moving) return;
    final first = _moving == null;
    _moving = moving;
    if (!moving) {
      _stopAll();
      if (first) {
        _look = widget.pose.still;
      } else {
        setState(() => _look = widget.pose.still);
      }
    } else {
      // The first appearance, or motion switched back on: play the pose once.
      _start(_RunKind.pose, from: null);
      _onGlancing();
    }
  }

  @override
  void didUpdateWidget(Wusel old) {
    super.didUpdateWidget(old);
    if (old.gazeAt != widget.gazeAt ||
        old.glancing != widget.glancing ||
        old.tilt != widget.tilt) {
      _unlisten(old);
      _listen(widget);
      _followTilt(_visible ? widget.tilt : null);
      _onGlancing();
    }
    if (old.still != widget.still) {
      _updateMotion();
      return;
    }
    if (old.pose == widget.pose && old.moment == widget.moment) return;
    if (_moving != true) {
      setState(() => _look = widget.pose.still);
      return;
    }
    _start(_RunKind.pose, from: _look);
  }

  @override
  void dispose() {
    _unlisten(widget);
    _stopAll();
    _ticker.dispose();
    super.dispose();
  }

  void _stopAll() {
    _blinkTimer?.cancel();
    _sleepTimer?.cancel();
    _restTimer?.cancel();
    _glanceTimer?.cancel();
    _hopTimer?.cancel();
    _blinkTimer = null;
    _sleepTimer = null;
    _restTimer = null;
    _glanceTimer = null;
    _hopTimer = null;
    _glance = Offset.zero;
    _run = null;
    _restPending = false;
    _rig.reset();
    if (_ticker.isTicking) _ticker.stop();
  }

  void _start(_RunKind kind, {required WuselLook? from}) {
    _blinkTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (_ticker.isTicking) _ticker.stop();
    // A hop of the afterglow is no moment of its own: the wall's rest timer runs on.
    if (kind == _RunKind.pose || kind == _RunKind.reaction) _momentNow();
    if (kind == _RunKind.pose && widget.pose == WuselPose.sleep) {
      _rig.reset();
      _fallAsleep(from: from);
      return;
    }
    _run = _Run(kind);
    _restPending = false;
    _blendFrom = from;
    _now = Duration.zero;
    _lastTick = Duration.zero;
    _blendStart = Duration.zero;
    _lastLift = null;
    _ticker.start();
  }

  /// Something outside moved (the finger, the tilt, a glance): draw frames until the
  /// springs have followed. Not while asleep, still or hidden.
  void _wake() {
    if (!mounted || _moving != true || !_visible) return;
    if (widget.pose == WuselPose.sleep || _ticker.isTicking) return;
    _lastTick = Duration.zero;
    _lastLift = null;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final pose = widget.pose;
    final run = _run;
    var next = pose.rest;
    if (run != null) {
      var done = false;
      switch (run.kind) {
        case _RunKind.pose:
          next = pose.at(elapsed);
          done = elapsed >= pose.active;
        case _RunKind.blink:
          final p = elapsed.inMicroseconds / _blinkLength.inMicroseconds;
          next = pose.rest.copyWith(
            eyeOpen: p >= 1 ? 1 : (1 - math.sin(math.pi * p)).clamp(0.0, 1.0),
          );
          done = elapsed >= _blinkLength;
        case _RunKind.reaction:
          final length = _tickle == _Tickle.wriggle
              ? _wriggleLength
              : _reactionLength;
          next = _reactionLook(pose.rest, elapsed, length);
          done = elapsed >= length;
        case _RunKind.hop:
          next = _hopLook(pose.rest, elapsed);
          done = elapsed >= _hopLength;
      }
      if (_blendFrom case final from?) {
        final t =
            (elapsed - _blendStart).inMicroseconds / _blend.inMicroseconds;
        if (t >= 1) {
          _blendFrom = null;
        } else {
          next = WuselLook.lerp(from, next, Curves.easeOutCubic.transform(t));
        }
      }
      if (done && _blendFrom == null) {
        _run = null;
        _restPending = true;
      }
    }
    // The body's own up and down, in sizes per second, drives the tufts and stretch.
    final lift = next.lift;
    final speed = _lastLift == null || dt <= 0
        ? 0.0
        : (lift - _lastLift!) / 100 / dt;
    _lastLift = lift;
    final input = _input(next);
    _rig.step(
      dt,
      velocity: Offset(0, _run == null ? 0 : speed),
      gaze: input.gaze,
      lean: input.lean,
      slide: input.slide,
      tufts: input.tufts,
    );
    setState(() => _look = _rig.apply(next));
    if (_run == null && _rig.atRest) _settle();
  }

  /// The springs have settled: stop drawing frames, holding what the inputs ask for
  /// (the eyes on the finger) on top of the pose's rest.
  void _settle() {
    _ticker.stop();
    _rig.snap();
    if (!mounted) return;
    final pending = _restPending;
    _restPending = false;
    if (pending && widget.pose == WuselPose.sleep) {
      // After a tap's reaction: back to sleep.
      setState(() => _fallAsleep(from: null));
      return;
    }
    setState(() => _look = _rig.apply(widget.pose.rest));
    if (pending && widget.pose.blinks) _scheduleBlink();
  }

  /// What the world outside asks of Wusel this frame: where to look, and how the
  /// tilt leans and slides it. The finger wins over the tilt, the tilt over a glance.
  ({Offset gaze, double lean, double slide, double tufts}) _input(
    WuselLook base,
  ) {
    final tilt = widget.tilt?.value ?? 0;
    _followedTilt = tilt;
    var gaze = _glance;
    final downhill = tilt.abs() > 0.15;
    if (downhill) gaze = Offset(3 * tilt, 1.5 * tilt.abs()) - base.gaze;
    final finger = widget.gazeAt?.value;
    if (finger != null) {
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        // Between the eyes: (50, 56) on the grid, in the drawing's frame.
        final s = box.size.shortestSide;
        final eye = box.localToGlobal(
          Offset(box.size.width / 2, (box.size.height - s) / 2 + s * 0.6),
        );
        gaze = gazeToward(eye, finger, poseGaze: base.gaze);
      }
    }
    final over = (tilt.abs() - 0.3).clamp(0.0, 0.7) / 0.7;
    return (
      gaze: gaze,
      lean: 0.3 * tilt,
      slide: 10 * over * tilt.sign,
      tufts: 0.5 * tilt,
    );
  }

  /// Sleeps: the breath and the "z" come from a slow timer instead of the ticker.
  /// Sets [_look] for the build that follows.
  void _fallAsleep({required WuselLook? from}) {
    _run = null;
    _blendFrom = from;
    _sleepClock = Duration.zero;
    _look = from ?? widget.pose.sleeping(Duration.zero);
    _sleepTimer?.cancel();
    _sleepTimer = _visible
        ? Timer.periodic(Wusel.sleepFrame, _onSleepFrame)
        : null;
  }

  void _onSleepFrame(Timer timer) {
    if (!mounted) return;
    if (!_visible) {
      // Hidden: no breath until the route shows again (see [_followVisibility]).
      timer.cancel();
      _sleepTimer = null;
      return;
    }
    _sleepClock += Wusel.sleepFrame;
    var next = widget.pose.sleeping(_sleepClock);
    if (_blendFrom case final from?) {
      final t = _sleepClock.inMicroseconds / _blend.inMicroseconds;
      if (t >= 1) {
        _blendFrom = null;
      } else {
        next = WuselLook.lerp(from, next, Curves.easeOutCubic.transform(t));
      }
    }
    setState(() => _look = next);
  }

  /// A moment happened: blink again, and rest [Wusel.restAfter] from now.
  void _momentNow() {
    _resting = false;
    _restTimer?.cancel();
    final after = widget.restAfter;
    _restTimer = after == null
        ? null
        : Timer(after, () {
            _resting = true;
            _blinkTimer?.cancel();
            _blinkTimer = null;
          });
  }

  void _scheduleBlink() {
    if (_resting) return;
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 3000 + _random.nextInt(4000)),
      () {
        if (!mounted) return;
        if (_visible && _run == null && !_ticker.isTicking) {
          _start(_RunKind.blink, from: null);
        } else {
          _scheduleBlink();
        }
      },
    );
  }

  /// The afterglow began or ended: glances and hops on the spot, or none.
  void _onGlancing() {
    final on =
        (widget.glancing?.value ?? false) &&
        _moving == true &&
        widget.pose != WuselPose.sleep;
    if (!on) {
      _glanceTimer?.cancel();
      _hopTimer?.cancel();
      _glanceTimer = null;
      _hopTimer = null;
      if (_glance != Offset.zero) {
        _glance = Offset.zero;
        _wake();
      }
      return;
    }
    _glanceTimer ??= _nextGlance();
    _hopTimer ??= _nextHop();
  }

  Timer _nextGlance() =>
      Timer(Duration(milliseconds: 1200 + _random.nextInt(2300)), () {
        if (!mounted) return;
        // Alternate: a look somewhere, then back to the front.
        _glance = _glance == Offset.zero
            ? Offset(
                (_random.nextDouble() * 2 - 1) * 2.5,
                (_random.nextDouble() * 2 - 1) * 1.8,
              )
            : Offset.zero;
        _wake();
        _glanceTimer = _nextGlance();
      });

  Timer _nextHop() =>
      Timer(Duration(milliseconds: 7000 + _random.nextInt(4000)), () {
        if (!mounted) return;
        if (_visible && _run == null && widget.pose != WuselPose.sleep) {
          _start(_RunKind.hop, from: null);
        }
        _hopTimer = _nextHop();
      });

  void _onTilt() {
    final tilt = widget.tilt?.value ?? 0;
    if ((tilt - _followedTilt).abs() >= _tiltStep) _wake();
  }

  /// Whether this Wusel is on a screen that can be seen: an offstage route mutes it.
  bool get _visible => TickerMode.valuesOf(context).enabled;

  WuselLook _reactionLook(WuselLook rest, Duration elapsed, Duration length) {
    final p = (elapsed.inMicroseconds / length.inMicroseconds).clamp(0.0, 1.0);
    final bump = math.sin(math.pi * p);
    return switch (_tickle) {
      // A giggle: a squash and happy eyes.
      _Tickle.giggle => rest.copyWith(
        squash: -0.08 * bump,
        eyes: p < 0.9 ? WuselEyes.happy : rest.eyes,
      ),
      // A tuft spin.
      _Tickle.spin => rest.copyWith(tuftSway: 0.6 * math.sin(2 * math.pi * p)),
      // A wink: one eye closes and opens again, with a little squash.
      _Tickle.wink => rest.copyWith(wink: bump, squash: -0.03 * bump),
      // Three taps in a row: a wriggling giggle, the body and the tufts shaking.
      _Tickle.wriggle => rest.copyWith(
        squash: 0.07 * bump * math.sin(2 * math.pi * 6 * p),
        lean: 0.12 * bump * math.sin(2 * math.pi * 4 * p),
        tuftSway: 0.45 * bump * math.sin(2 * math.pi * 5 * p),
        eyes: p < 0.92 ? WuselEyes.happy : rest.eyes,
        mouth: p < 0.92 ? WuselMouth.open : rest.mouth,
      ),
    };
  }

  /// A small hop on the spot in the afterglow: a crouch, up, and down.
  WuselLook _hopLook(WuselLook rest, Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    if (t < 0.1) return rest.copyWith(squash: -0.08 * (t / 0.1));
    if (t < 0.42) {
      final p = (t - 0.1) / 0.32;
      return rest.copyWith(
        lift: -10 * math.sin(math.pi * p),
        squash: 0.06 * math.sin(math.pi * p),
        feet: true,
        tuftLift: 0.4 * math.sin(math.pi * p),
      );
    }
    return rest;
  }

  void _tap(TapUpDetails details) {
    widget.onTap?.call();
    if (_moving != true) return;
    final s = widget.size;
    final at = details.localPosition;
    // Three taps within 1.5 s give the wriggle; otherwise where the finger landed
    // decides: the tufts spin, near the eyes a wink, anywhere else a giggle.
    final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    _taps
      ..add(now)
      ..removeWhere((t) => now - t > const Duration(milliseconds: 1500));
    if (_taps.length >= 3) {
      _taps.clear();
      _tickle = _Tickle.wriggle;
    } else if (at.dy < s * 0.36) {
      _tickle = _Tickle.spin;
    } else if ((at.dy - s * 0.6).abs() < s * 0.1 &&
        (at.dx - s / 2).abs() < s * 0.22) {
      _tickle = _Tickle.wink;
    } else {
      _tickle = _Tickle.giggle;
    }
    _start(_RunKind.reaction, from: _look);
    _rig.wobble(strength: _tickle == _Tickle.wriggle ? 1.4 : 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (size < Wusel.minSize) return SizedBox.square(dimension: size);
    Widget drawing = CustomPaint(
      size: Size.square(size),
      painter: WuselPainter(
        look: _look,
        colors: widget.colors,
        outfit: widget.outfit,
        frontTuft: widget.frontTuft,
      ),
    );
    if (widget.pose == WuselPose.peek) drawing = _peek(drawing, size);
    if (widget.onTap != null) {
      drawing = GestureDetector(
        onTapUp: _tap,
        behavior: HitTestBehavior.opaque,
        child: drawing,
      );
    }
    return ExcludeSemantics(child: RepaintBoundary(child: drawing));
  }

  /// Only the top of Wusel shows, as if over the lower edge of a card. On arrival it
  /// rises into view once.
  Widget _peek(Widget drawing, double size) {
    final window = size * _peekWindow;
    final rise = _run?.kind == _RunKind.pose && _moving == true
        ? Curves.easeOutBack.transform(
            (_now.inMicroseconds / WuselPose.peek.active.inMicroseconds).clamp(
              0.0,
              1.0,
            ),
          )
        : 1.0;
    return SizedBox(
      width: size,
      height: window,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: size,
          maxHeight: size,
          child: Transform.translate(
            offset: Offset(0, (1 - rise) * window),
            child: drawing,
          ),
        ),
      ),
    );
  }

  /// The eyes sit at 60 % of the frame; a little more shows the cheeks' top.
  static const _peekWindow = 0.68;
}

enum _RunKind { pose, blink, reaction, hop }

/// The tickles of specs/25 "Wusel on the move".
enum _Tickle { giggle, spin, wink, wriggle }

class _Run {
  _Run(this.kind);

  final _RunKind kind;
}
