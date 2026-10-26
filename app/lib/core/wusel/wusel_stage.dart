import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel_look.dart';
import 'package:wuselwall/core/wusel/wusel_painter.dart';
import 'package:wuselwall/core/wusel/wusel_pose.dart';
import 'package:wuselwall/core/wusel/wusel_rig.dart';
import 'package:wuselwall/core/wusel/wusel_travel.dart';

/// How a home's Wusel looks, so the one that travels is the same character: the
/// family's tufts in the current shade, the outfit, the front tuft.
@immutable
class WuselAppearance {
  const WuselAppearance({
    required this.colors,
    this.outfit = WuselOutfit.none,
    this.frontTuft,
  });

  final WuselColors colors;
  final WuselOutfit outfit;
  final int? frontTuft;

  @override
  bool operator ==(Object other) =>
      other is WuselAppearance &&
      other.colors == colors &&
      other.outfit == outfit &&
      other.frontTuft == frontTuft;

  @override
  int get hashCode => Object.hash(colors, outfit, frontTuft);
}

/// Where on a target's box Wusel goes for a visit.
enum WuselSpot {
  /// Sitting on the box's upper edge at its start: on a chore card, the end away from
  /// the tick (specs/25 "Wusel on the move").
  topStart,

  /// In the box: a space a screen keeps for Wusel.
  inside,
}

/// The stage Wusel travels on (specs/25 "Wusel on the move"). It sits above the
/// navigator, so a trip can go over a dialog, and it holds the one Wusel that is away
/// from its home. It draws frames only while a trip runs.
///
/// It also keeps the finger's last position for the eyes, read by a [Listener] that
/// takes no touch, and the afterglow: the 30 s after a moment in which a home's Wusel
/// is awake.
class WuselStage extends StatefulWidget {
  const WuselStage({required this.child, super.key});

  final Widget child;

  /// The stage above [context], or null (a test that pumps one page, a screen
  /// outside the app): then Wusel simply stays in its box.
  static WuselStageState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_StageScope>()?.state;

  /// How long Wusel stays awake after a moment.
  static const afterglowFor = Duration(seconds: 30);

  /// The longest a visit lasts before Wusel goes home by itself.
  static const visitFor = Duration(seconds: 4);

  @override
  State<WuselStage> createState() => WuselStageState();
}

class WuselStageState extends State<WuselStage>
    with SingleTickerProviderStateMixin {
  /// Where the finger last touched the screen, in global coordinates, while a Wusel
  /// is following it; null otherwise.
  final finger = ValueNotifier<Offset?>(null);

  /// True for [WuselStage.afterglowFor] after a moment.
  final afterglow = ValueNotifier<bool>(false);

  final _homes = <WuselHomeState>[];
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  final _frame = _Frame();
  final _box = GlobalKey();

  Timer? _afterglowTimer;
  Timer? _followTimer;
  bool _following = false;

  WuselTrip? _trip;

  /// The trip under way, if any.
  @visibleForTesting
  WuselTrip? get trip => _trip;

  @override
  void dispose() {
    _afterglowTimer?.cancel();
    _followTimer?.cancel();
    _trip?._finish();
    _ticker.dispose();
    finger.dispose();
    afterglow.dispose();
    super.dispose();
  }

  // --- Homes ---------------------------------------------------------------

  void _register(WuselHomeState home) => _homes.add(home);

  void _unregister(WuselHomeState home) {
    _homes.remove(home);
    // A screen that went away takes its home with it: the traveller has nowhere to
    // go and is simply gone (specs/25: "or is simply at home").
    if (_trip?.home == home) _trip!._finish();
  }

  /// The home a trip starts from: the newest one that can be seen and travels.
  WuselHomeState? get _home {
    for (final h in _homes.reversed) {
      if (h.widget.travels && h._onScreen) return h;
    }
    return null;
  }

  /// Whether a visit could start now: there is a home that travels, nothing else is
  /// travelling, and motion is allowed. A screen asks this to choose its layout.
  bool get canVisit => _trip == null && _motion && _home != null;

  bool get _motion => mounted && motionAllowed(context);

  // --- Moments and the finger ----------------------------------------------

  /// A moment happened: the home's Wusel stays awake for [WuselStage.afterglowFor],
  /// and its eyes follow the finger meanwhile.
  void moment() {
    if (!_motion) return;
    afterglow.value = true;
    _following = true;
    _followTimer?.cancel();
    _afterglowTimer?.cancel();
    _afterglowTimer = Timer(WuselStage.afterglowFor, () {
      afterglow.value = false;
      _stopFollowing();
    });
  }

  /// The eyes follow the finger for [span], without the rest of the afterglow: the
  /// wall's Wusel after a tap, which stays in its corner.
  void followFinger(Duration span) {
    if (!_motion) return;
    _following = true;
    _followTimer?.cancel();
    _followTimer = Timer(span, () {
      if (!afterglow.value) _stopFollowing();
    });
  }

  void _stopFollowing() {
    _following = false;
    finger.value = null;
  }

  void _onPointer(PointerEvent event) {
    if (_following) finger.value = event.position;
  }

  // --- Trips -----------------------------------------------------------------

  /// Sends Wusel from its home to [target] (specs/25 "Wusel on the move"). Returns
  /// null when Wusel cannot go: no home that travels, a trip under way, reduced
  /// motion, or the target is not on screen. The caller then does what it did before
  /// Wusel could travel.
  ///
  /// Wusel stays at the target until [WuselTrip.goHome] or [WuselStage.visitFor]; with
  /// [stay] set it goes home by itself after that time. [pose] is what it does while
  /// it is there (the wall's cheer beside a column); without one it looks at the
  /// target.
  WuselTrip? visit(
    GlobalKey target, {
    WuselSpot spot = WuselSpot.topStart,
    double? size,
    Duration? stay,
    WuselPose? pose,
  }) {
    final home = _home;
    if (!canVisit || home == null) return null;
    final s = size ?? home.widget.size;
    Offset? where() => _spotOf(target, spot, s);
    final start = home._centre;
    final first = where();
    if (start == null || first == null) return null;
    final trip = WuselTrip._(
      this,
      home,
      start: start,
      size: home.widget.size,
      out: where,
      visitSize: s,
      stay: stay,
      stayPose: pose,
    );
    _begin(trip);
    return trip;
  }

  /// Wusel comes into its [home] from the lower edge of the screen: back on *Mein
  /// Tag* from another tab. False when it cannot (the home then shows Wusel at once).
  bool enter(WuselHomeState home) {
    if (_trip != null || !_motion || !home._onScreen) return false;
    final centre = home._centre;
    final screen = _screen;
    if (centre == null || screen == null) return false;
    final trip = WuselTrip._(
      this,
      home,
      start: Offset(centre.dx, screen.bottom + home.widget.size * 0.6),
      size: home.widget.size,
      out: null,
      visitSize: home.widget.size,
    );
    _begin(trip);
    return true;
  }

  void _begin(WuselTrip trip) {
    _trip = trip;
    trip.home._setAway(true);
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final trip = _trip;
    if (trip == null) {
      _ticker.stop();
      return;
    }
    trip._advance(dt);
    _frame.changed();
  }

  void _ended(WuselTrip trip) {
    if (_trip != trip) return;
    _trip = null;
    if (_ticker.isActive) _ticker.stop();
    _frame.changed();
  }

  Rect? get _screen {
    final box = _box.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The centre of Wusel's square at [spot] of [target], in global coordinates, or
  /// null when the target is gone or not on screen.
  Offset? _spotOf(GlobalKey target, WuselSpot spot, double size) {
    final context = target.currentContext;
    final box = context?.findRenderObject();
    final screen = _screen;
    if (context == null ||
        box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        screen == null ||
        !TickerMode.valuesOf(context).enabled) {
      return null;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final Offset centre;
    switch (spot) {
      case WuselSpot.inside:
        centre = rect.center;
      case WuselSpot.topStart:
        final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
        // The feet sit at 86 % of Wusel's square (the body's bottom on the grid);
        // a little lower, so it sits on the edge rather than above it.
        final x = rtl ? rect.right - size * 0.55 : rect.left + size * 0.55;
        centre = Offset(x, rect.top - size * 0.30);
    }
    final square = Rect.fromCenter(center: centre, width: size, height: size);
    // Only between places that can be seen: most of Wusel must be on screen.
    final seen = square.intersect(screen);
    if (seen.isEmpty || seen.width * seen.height < size * size * 0.6) {
      return null;
    }
    return centre;
  }

  @override
  Widget build(BuildContext context) => _StageScope(
    state: this,
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointer,
      onPointerMove: _onPointer,
      child: Stack(
        key: _box,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _TravellerPainter(this, _frame)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StageScope extends InheritedWidget {
  const _StageScope({required this.state, required super.child});

  final WuselStageState state;

  @override
  bool updateShouldNotify(_StageScope old) => old.state != state;
}

class _Frame extends ChangeNotifier {
  void changed() => notifyListeners();
}

class _TravellerPainter extends CustomPainter {
  _TravellerPainter(this.stage, _Frame frame) : super(repaint: frame);

  final WuselStageState stage;

  @override
  void paint(Canvas canvas, Size size) {
    final trip = stage._trip;
    if (trip == null || trip._finished) return;
    final box = stage._box.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final centre = box.globalToLocal(trip.position);
    final s = trip.size;
    final appearance = trip.home.widget.appearance;
    canvas
      ..save()
      ..translate(centre.dx - s / 2, centre.dy - s / 2);
    WuselPainter(
      look: trip.look,
      colors: appearance.colors,
      outfit: appearance.outfit,
      frontTuft: appearance.frontTuft,
    ).paint(canvas, Size.square(s));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TravellerPainter old) => old.stage != stage;
}

enum _Phase { crouch, flight, stay, jump, settle }

/// One trip of Wusel's: out to a target, a stay, and home again; or only the way
/// home, when Wusel comes in from the edge of the screen.
class WuselTrip {
  WuselTrip._(
    this._stage,
    this.home, {
    required Offset start,
    required double size,
    required Offset? Function()? out,
    required double visitSize,
    Duration? stay,
    this._stayPose,
  }) : position = start,
       size = size,
       _homeSize = size,
       _visitSize = visitSize,
       _out = out,
       _stayFor = stay {
    if (out != null) {
      _startLeg(out, toSize: visitSize, outward: true);
    } else {
      // Coming in from the edge: at most two big leaps, however tall the screen.
      _startLeg(
        () => home._centre,
        toSize: _homeSize,
        outward: false,
        maxHops: 2,
      );
    }
  }

  final WuselStageState _stage;
  final WuselHomeState home;

  /// Where Wusel's centre is, in global coordinates, and how big it is drawn.
  Offset position;
  double size;

  /// What Wusel looks like this frame.
  WuselLook look = const WuselLook();

  final double _homeSize;
  final double _visitSize;
  final Offset? Function()? _out;
  final Duration? _stayFor;
  final WuselPose? _stayPose;
  final _rig = WuselRig();

  final _arrived = Completer<void>();
  final _done = Completer<void>();

  /// Completes when Wusel has reached the target (never, if it turned back early).
  Future<void> get arrived => _arrived.future;

  /// Completes when Wusel is home again, or the trip ended because its home went.
  Future<void> get done => _done.future;

  // The leg under way.
  late Offset _legFrom;
  late Offset? Function() _legTo;
  late int _hops;
  late double _legSizeFrom;
  late double _legSizeTo;
  bool _outward = true;
  int _hop = 0;

  // The hop or phase under way.
  _Phase _phase = _Phase.crouch;
  double _t = 0;
  double _crouch = WuselHops.firstCrouch;
  WuselHopPath? _path;
  Offset _velocity = Offset.zero;

  // What happens after the stay.
  bool _released = false;
  bool _happy = false;
  bool _celebrate = false;
  bool _carry = false;
  void Function(Offset hand)? _onHome;
  bool _finished = false;

  /// Sends Wusel home from its visit. [happy] shows the happy eyes on the way,
  /// [celebrate] makes a high cheering jump first, [carry] holds up the coin, and
  /// [onHome] is called with the coin's position once Wusel is home. Before Wusel has
  /// arrived, it goes home right after arriving.
  void goHome({
    bool happy = false,
    bool celebrate = false,
    bool carry = false,
    void Function(Offset hand)? onHome,
  }) {
    if (_released || _finished) return;
    _released = true;
    _happy = happy;
    _celebrate = celebrate;
    _carry = carry;
    _onHome = onHome;
  }

  /// Whether Wusel came home carrying something, which [goHome]'s `onHome` was then
  /// handed: the caller takes it from there.
  bool get carriedHome => _finished && _reachedHome && _carry;
  bool _reachedHome = false;

  /// Where the coin is in Wusel's hand, in global coordinates.
  Offset get hand {
    // The coin's centre on the grid (see WuselPainter._coin), in the square.
    const grid = Offset(98.9, 43);
    final f = WuselPainter.frame;
    return position -
        Offset(size / 2, size / 2) +
        Offset(
          (grid.dx - f.left) / f.width * size,
          (grid.dy - f.top) / f.height * size,
        );
  }

  void _startLeg(
    Offset? Function() to, {
    required double toSize,
    required bool outward,
    int? maxHops,
  }) {
    final dest = to();
    if (dest == null) {
      _turnBack();
      return;
    }
    _outward = outward;
    _legFrom = position;
    _legTo = to;
    _hops = WuselHops.count(position, dest, size);
    if (maxHops != null && _hops > maxHops) _hops = maxHops;
    _legSizeFrom = size;
    _legSizeTo = toSize;
    _hop = 0;
    _beginHop(first: true);
  }

  Offset? _waypoint(int k) {
    final dest = _legTo();
    if (dest == null) return null;
    return Offset.lerp(_legFrom, dest, k / _hops);
  }

  void _beginHop({required bool first}) {
    final to = _waypoint(_hop + 1);
    if (to == null) {
      _turnBack();
      return;
    }
    final length = (to - position).distance;
    _path = WuselHopPath(
      from: position,
      height: WuselHops.arcHeight(length, size),
      seconds: WuselHops.flightSeconds(length, size),
    );
    _crouch = first ? WuselHops.firstCrouch : WuselHops.nextCrouch;
    _phase = _Phase.crouch;
    _t = 0;
  }

  /// The target went away or out of sight: home at once; and if home is gone too,
  /// the trip is over.
  void _turnBack() {
    if (!_outward || home._centre == null) {
      _finish();
      return;
    }
    _released = true;
    _startLeg(() => home._centre, toSize: _homeSize, outward: false);
  }

  void _advance(double dt) {
    if (_finished) return;
    _t += dt;
    var base = const WuselLook();
    final flightLook = WuselLook(
      feet: true,
      tuftLift: 0.5,
      eyes: _happy || _celebrate ? WuselEyes.happy : WuselEyes.round,
      armLeft: 1.2,
      armRight: _carry ? 2.4 : 1.2,
      prop: _carry ? WuselProp.coin : WuselProp.none,
    );
    var gaze = Offset.zero;
    switch (_phase) {
      case _Phase.crouch:
        final p = (_t / _crouch).clamp(0.0, 1.0);
        base = WuselLook(
          squash: -0.12 * wuselEase(p),
          eyes: flightLook.eyes,
          armRight: _carry ? 2.4 : null,
          prop: flightLook.prop,
        );
        gaze = _lookToward(_waypoint(_hop + 1), base.gaze);
        if (_t >= _crouch) {
          final to = _waypoint(_hop + 1);
          _rig.takeOff(
            sideways: to == null ? 0 : (to.dx - position.dx).sign.toDouble(),
          );
          _phase = _Phase.flight;
          _t = 0;
        }
      case _Phase.flight:
        final path = _path!;
        final to = _waypoint(_hop + 1);
        if (to == null) {
          _turnBack();
          return;
        }
        final p = (_t / path.seconds).clamp(0.0, 1.0);
        position = path.at(p, to);
        _velocity = path.velocity(p, to);
        size = lerpDouble(_legSizeFrom, _legSizeTo, (_hop + p) / _hops)!;
        base = flightLook;
        gaze = _lookToward(to, base.gaze);
        if (p >= 1) {
          _velocity = Offset.zero;
          _rig.land(strength: _hop + 1 == _hops ? 1 : 0.6);
          _hop++;
          if (_hop < _hops) {
            _beginHop(first: false);
          } else if (_outward) {
            _phase = _Phase.stay;
            _t = 0;
            if (!_arrived.isCompleted) _arrived.complete();
          } else {
            _phase = _Phase.settle;
            _t = 0;
          }
        }
      case _Phase.stay:
        final at = _out?.call();
        if (at == null) {
          _turnBack();
          return;
        }
        position = at;
        // Looking down at the card, or as the screen asked.
        base =
            _stayPose?.at(Duration(microseconds: (_t * 1e6).round())) ??
            WuselLook(
              gaze: const Offset(1, 4),
              eyes: _happy || _carry ? WuselEyes.happy : WuselEyes.round,
              armRight: _carry ? 2.4 : null,
              prop: _carry ? WuselProp.coin : WuselProp.none,
            );
        final timedOut =
            _t >= (_stayFor ?? WuselStage.visitFor).inMicroseconds / 1e6;
        if (timedOut) _released = true;
        // A short look at the card first, so the visit reads as one.
        if (_released && _t >= 0.3) {
          if (_celebrate) {
            _phase = _Phase.jump;
            _t = 0;
            _rig.takeOff(strength: 1.4);
          } else {
            _startLeg(() => home._centre, toSize: _homeSize, outward: false);
          }
        }
      case _Phase.jump:
        final at = _out?.call() ?? position;
        const seconds = 0.8;
        final p = (_t / seconds).clamp(0.0, 1.0);
        final height = _visitSize * 1.4;
        position = at + Offset(0, -4 * height * p * (1 - p));
        _velocity = Offset(0, -4 * height * (1 - 2 * p) / seconds);
        size = _visitSize * (1 + 0.25 * 4 * p * (1 - p));
        base = WuselLook(
          eyes: WuselEyes.happy,
          mouth: WuselMouth.open,
          tuftLift: 1,
          armLeft: 2.5,
          armRight: 2.5,
          feet: true,
          confetti: p,
        );
        if (p >= 1) {
          _velocity = Offset.zero;
          size = _visitSize;
          _rig.land(strength: 1.2);
          _celebrate = false;
          _happy = true;
          _startLeg(() => home._centre, toSize: _homeSize, outward: false);
        }
      case _Phase.settle:
        final at = home._centre;
        if (at == null) {
          _finish();
          return;
        }
        position = at;
        size = _homeSize;
        base = WuselLook(
          eyes: _happy ? WuselEyes.happy : WuselEyes.round,
          armRight: _carry ? 2.4 : null,
          prop: _carry ? WuselProp.coin : WuselProp.none,
        );
        // Home: once the landing has bounced out, the home's own Wusel takes over.
        if (_t >= 0.25) {
          _finish(home: true);
          return;
        }
    }
    _rig.step(dt, velocity: _velocity / size, gaze: gaze);
    look = _rig.apply(base);
  }

  /// Looks the way Wusel is about to go.
  Offset _lookToward(Offset? to, Offset poseGaze) {
    if (to == null) return Offset.zero;
    final d = to - position;
    if (d.distance < 1) return Offset.zero;
    return d / d.distance * 3 - poseGaze;
  }

  void _finish({bool home = false}) {
    if (_finished) return;
    _finished = true;
    final hand = this.hand;
    this.home._setAway(false);
    _stage._ended(this);
    if (home) {
      _reachedHome = true;
      if (this.home.widget.afterglow) _stage.moment();
      _onHome?.call(hand);
    }
    if (!_done.isCompleted) _done.complete();
  }
}

/// A place Wusel lives on a screen (specs/25 "Wusel on the move": one Wusel, one
/// home). It registers its box with the [WuselStage] and shows its [child] (the
/// Wusel drawn in its box) except while Wusel is away on a trip; the space stays, so
/// nothing on the screen shifts.
class WuselHome extends StatefulWidget {
  const WuselHome({
    required this.appearance,
    required this.size,
    required this.child,
    this.travels = true,
    this.afterglow = false,
    this.enter = false,
    super.key,
  });

  final WuselAppearance appearance;

  /// The edge of the square Wusel is drawn in here.
  final double size;
  final Widget child;

  /// Whether Wusel may leave this home: a lively Wusel that is not asleep or
  /// thinking.
  final bool travels;

  /// Whether a trip that ends here starts the afterglow (the kid register).
  final bool afterglow;

  /// Whether Wusel comes in from the lower edge when this home appears.
  final bool enter;

  @override
  State<WuselHome> createState() => WuselHomeState();
}

class WuselHomeState extends State<WuselHome> {
  WuselStageState? _stage;
  final _away = ValueNotifier<bool>(false);
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage = WuselStage.maybeOf(context);
    if (stage != _stage) {
      _stage?._unregister(this);
      _stage = stage;
      stage?._register(this);
    }
    if (widget.enter && !_entered && stage != null) {
      _entered = true;
      if (widget.travels && motionAllowed(context)) {
        // Away from the first frame, so Wusel does not flash at home first.
        _away.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!(_stage?.enter(this) ?? false)) _away.value = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stage?._unregister(this);
    _away.dispose();
    super.dispose();
  }

  void _setAway(bool away) {
    if (mounted) _away.value = away;
  }

  Rect? get _rect {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The centre of this home's square, in global coordinates.
  Offset? get _centre => _rect?.center;

  bool get _onScreen {
    final rect = _rect;
    final screen = _stage?._screen;
    if (rect == null || screen == null) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    return screen.contains(rect.center);
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: ValueListenableBuilder<bool>(
      valueListenable: _away,
      builder: (context, away, child) =>
          Opacity(opacity: away ? 0 : 1, child: child),
      child: widget.child,
    ),
  );
}
