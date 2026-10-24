import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel_look.dart';
import 'package:wuselwall/core/wusel/wusel_painter.dart';
import 'package:wuselwall/core/wusel/wusel_pose.dart';

export 'package:wuselwall/core/wusel/wusel_look.dart' show WuselOutfit;
export 'package:wuselwall/core/wusel/wusel_painter.dart' show WuselColors;
export 'package:wuselwall/core/wusel/wusel_pose.dart';

/// Wusel, the family's companion (specs/25), in one [pose].
///
/// The pose moves for a moment and then rests: the widget draws frames only while
/// something is happening (the pose's own motion, a blink), so a wall that shows Wusel
/// all day is not redrawing it all day. A sleeping Wusel breathes all night, but at
/// [sleepFrame] intervals from a timer rather than on every frame, and not at all
/// while its route is hidden. Under reduced motion ([motionAllowed]) it shows the
/// pose's still look and never ticks.
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

  /// A tap gives one of three small reactions (specs/25 "Poses"); null for none.
  final VoidCallback? onTap;

  /// Holds the pose's still look, as under reduced motion: a quiet Wusel, a picker.
  final bool still;

  /// Stops the idle blink this long after the last moment (a new pose, [moment] or a
  /// tap), until the next one: the wall rests after 60 s (specs/25 "Power on the
  /// wall"). Null blinks for as long as Wusel is shown.
  final Duration? restAfter;

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

  /// What is moving right now; null while resting.
  _Run? _run;
  Duration _now = Duration.zero;
  WuselLook? _blendFrom;
  Duration _blendStart = Duration.zero;
  late WuselLook _look = widget.pose.still;

  Timer? _blinkTimer;
  int _reaction = 0;

  /// Draws the sleeping look at [Wusel.sleepFrame] intervals while [WuselPose.sleep]
  /// rests; [_sleepClock] is how long Wusel has slept, counted in those frames.
  Timer? _sleepTimer;
  Duration _sleepClock = Duration.zero;

  /// Runs from the last moment until [Wusel.restAfter]; once it has fired, no blink is
  /// scheduled until the next moment.
  Timer? _restTimer;
  bool _resting = false;

  static const _blend = Duration(milliseconds: 250);
  static const _blinkLength = Duration(milliseconds: 180);
  static const _reactionLength = Duration(milliseconds: 600);

  /// Null until the first build has asked [motionAllowed].
  bool? _moving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
    _followVisibility();
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
    }
  }

  @override
  void didUpdateWidget(Wusel old) {
    super.didUpdateWidget(old);
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
    _stopAll();
    _ticker.dispose();
    super.dispose();
  }

  void _stopAll() {
    _blinkTimer?.cancel();
    _sleepTimer?.cancel();
    _restTimer?.cancel();
    _blinkTimer = null;
    _sleepTimer = null;
    _restTimer = null;
    _run = null;
    if (_ticker.isTicking) _ticker.stop();
  }

  void _start(_RunKind kind, {required WuselLook? from}) {
    _blinkTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (_ticker.isTicking) _ticker.stop();
    if (kind == _RunKind.pose || kind == _RunKind.reaction) _momentNow();
    if (kind == _RunKind.pose && widget.pose == WuselPose.sleep) {
      _fallAsleep(from: from);
      return;
    }
    _run = _Run(kind);
    _blendFrom = from;
    _now = Duration.zero;
    _blendStart = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    final run = _run;
    if (run == null) return;
    final pose = widget.pose;
    WuselLook next;
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
        next = _reactionLook(pose.rest, elapsed);
        done = elapsed >= _reactionLength;
    }
    if (_blendFrom case final from?) {
      final t = (elapsed - _blendStart).inMicroseconds / _blend.inMicroseconds;
      if (t >= 1) {
        _blendFrom = null;
      } else {
        next = WuselLook.lerp(from, next, Curves.easeOutCubic.transform(t));
      }
    }
    setState(() => _look = next);
    if (done && _blendFrom == null) _rest();
  }

  /// The pose has moved; it now holds still until a blink or its own moment.
  void _rest() {
    _run = null;
    _ticker.stop();
    if (!mounted) return;
    if (widget.pose == WuselPose.sleep) {
      // After a tap's reaction: back to sleep.
      setState(() => _fallAsleep(from: null));
      return;
    }
    setState(() => _look = widget.pose.rest);
    if (widget.pose.blinks) _scheduleBlink();
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
    _blinkTimer = Timer(
      Duration(milliseconds: 3000 + _random.nextInt(4000)),
      () {
        if (!mounted) return;
        if (_visible && _run == null) {
          _start(_RunKind.blink, from: null);
        } else {
          _scheduleBlink();
        }
      },
    );
  }

  /// Whether this Wusel is on a screen that can be seen: an offstage route mutes it.
  bool get _visible => TickerMode.valuesOf(context).enabled;

  WuselLook _reactionLook(WuselLook rest, Duration elapsed) {
    final p = (elapsed.inMicroseconds / _reactionLength.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    final bump = math.sin(math.pi * p);
    return switch (_reaction % 3) {
      // A giggle: a squash and happy eyes.
      0 => rest.copyWith(
        squash: -0.08 * bump,
        eyes: p < 0.9 ? WuselEyes.happy : rest.eyes,
      ),
      // A tuft spin.
      1 => rest.copyWith(tuftSway: 0.6 * math.sin(2 * math.pi * p)),
      // A wink: one quick blink.
      _ => rest.copyWith(eyeOpen: 1 - bump),
    };
  }

  void _tap() {
    widget.onTap?.call();
    if (_moving != true) return;
    _reaction++;
    _start(_RunKind.reaction, from: _look);
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
        onTap: _tap,
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

enum _RunKind { pose, blink, reaction }

class _Run {
  _Run(this.kind);

  final _RunKind kind;
}
