import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/error_mapper.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';

/// Renders an [AsyncValue] with consistent loading and error states, so feature screens
/// only write their data branch. The error branch offers a retry.
///
/// A quick load never flashes a spinner: it shows only after [DelayedSpinner.delay], and
/// the content that replaces it fades in over it (specs/17 "Motion", 150 ms). Under
/// reduced motion the content simply takes the spinner's place.
///
/// With [keepPrevious], a view that steps through windows (a week, then the next) keeps
/// showing the last window's content, dimmed and inert, while the next one loads,
/// instead of blanking to a spinner.
class AsyncValueView<T> extends StatefulWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.onRetry,
    this.keepPrevious = false,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool keepPrevious;

  @override
  State<AsyncValueView<T>> createState() => _AsyncValueViewState<T>();
}

enum _Shown { loading, data, error }

class _AsyncValueViewState<T> extends State<AsyncValueView<T>>
    with TickerProviderStateMixin {
  /// The spinner's delayed fade in while a load runs. Its delay is a wait, not a
  /// motion, so it is not shortened when animations are off.
  late final AnimationController _spinner = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  CurvedAnimation? _spinnerCurve;
  Animation<double> get _spinnerOpacity =>
      _spinnerCurve ?? kAlwaysDismissedAnimation;

  /// The content's fade in after a load; at rest at 1.
  late final AnimationController _fadeIn = AnimationController(
    vsync: this,
    duration: Tokens.motionStandard,
    value: 1,
  )..addStatusListener(_settled);

  /// What the last build showed, to see a load start and end.
  _Shown? _shown;

  /// Whether the spinner is still fading out above the content that replaced it.
  bool _spinnerLeaving = false;

  /// The last content built, for [AsyncValueView.keepPrevious].
  Widget? _previous;

  void _settled(AnimationStatus status) {
    if (status.isCompleted && _spinnerLeaving && mounted) {
      setState(() => _spinnerLeaving = false);
    }
  }

  _Shown _shownOf(AsyncValue<T> value) => value.when(
    data: (_) => _Shown.data,
    error: (_, _) => _Shown.error,
    loading: () =>
        widget.keepPrevious && _previous != null ? _Shown.data : _Shown.loading,
  );

  /// Starts the spinner's clock when a load begins, and fades the content in over the
  /// spinner when it ends, if the spinner had begun to show.
  void _follow(_Shown now, {required bool moves}) {
    final was = _shown;
    _shown = now;
    if (now == was) return;
    if (now == _Shown.loading) {
      _spinnerLeaving = false;
      _fadeIn.value = 1;
      _spinnerCurve?.dispose();
      _spinnerCurve = delayedSpinnerOpacity(_spinner, moves: moves);
      _spinner.forward(from: 0);
    } else if (was == _Shown.loading) {
      _spinner.stop();
      if (moves) {
        _spinnerLeaving = _spinnerOpacity.value > 0;
        _fadeIn.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _spinnerCurve?.dispose();
    _spinner.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moves = motionAllowed(context);
    _follow(_shownOf(widget.value), moves: moves);
    final content = widget.value.when(
      data: (value) {
        final built = widget.data(value);
        if (!widget.keepPrevious) return built;
        _previous = built;
        return LoadingDim(stale: false, child: built);
      },
      loading: () => switch (_previous) {
        final previous? when widget.keepPrevious => LoadingDim(
          stale: true,
          child: previous,
        ),
        _ => Center(child: _spinnerOf(_spinnerOpacity)),
      },
      error: (error, _) => ErrorView(error: error, onRetry: widget.onRetry),
    );
    if (!moves) return content;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        FadeTransition(opacity: _fadeIn, child: content),
        if (_spinnerLeaving)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(_fadeIn),
                child: Center(child: _spinnerOf(_spinnerOpacity)),
              ),
            ),
          ),
      ],
    );
  }
}

Widget _spinnerOf(Animation<double> opacity) =>
    FadeTransition(opacity: opacity, child: const CircularProgressIndicator());

/// Sets [show] up to run a spinner's appearance and returns its opacity: nothing for
/// [DelayedSpinner.delay], then a fade in over 150 ms, or (when nothing [moves]) at
/// once.
CurvedAnimation delayedSpinnerOpacity(
  AnimationController show, {
  required bool moves,
}) {
  const delay = DelayedSpinner.delay;
  if (!moves) {
    show.duration = delay;
    return CurvedAnimation(parent: show, curve: const Threshold(1));
  }
  final total = delay + Tokens.motionStandard;
  show.duration = total;
  return CurvedAnimation(
    parent: show,
    curve: Interval(
      delay.inMicroseconds / total.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
}

/// A [CircularProgressIndicator] that stays invisible for [delay] and then fades in,
/// so a load that is over quickly never flashes it. Under reduced motion it appears
/// after the delay without the fade.
class DelayedSpinner extends StatefulWidget {
  const DelayedSpinner({super.key});

  /// How long a load may take before anything says it is loading.
  static const delay = Duration(milliseconds: 200);

  @override
  State<DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<DelayedSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  CurvedAnimation? _opacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opacity != null) return;
    _opacity = delayedSpinnerOpacity(_show, moves: motionAllowed(context));
    _show.forward();
  }

  @override
  void dispose() {
    _opacity?.dispose();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _spinnerOf(_opacity!);
}

/// Content that is still shown while what replaces it loads: dimmed, inert, and with a
/// [DelayedSpinner] over it once the load takes a while. Wrap the content whether it is
/// stale or not, so it keeps its state when it turns fresh again.
class LoadingDim extends StatelessWidget {
  const LoadingDim({required this.stale, required this.child, super.key});

  final bool stale;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      IgnorePointer(
        ignoring: stale,
        child: AnimatedOpacity(
          opacity: stale ? 0.5 : 1,
          duration: motionAllowed(context)
              ? Tokens.motionStandard
              : Duration.zero,
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
      if (stale)
        const Positioned.fill(
          child: IgnorePointer(child: Center(child: DelayedSpinner())),
        ),
    ],
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(mapError(error).message(l10n), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}
