import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';

/// The minute wheel's step. Bell times, trainings and appointments are almost always
/// on one; the rest is one tap on [AppLocalizations.timeWheelExact] away.
const timeWheelStep = 5;

/// Asks for a time of day with two wheels, hours and minutes, in a sheet from the
/// bottom (specs/17 "Choosing a time"). The one way the app asks for a time: no clock
/// dial, no switch between hours and minutes.
///
/// The minutes move in steps of [timeWheelStep] until the person asks for every minute;
/// an [initial] time that is on no step opens with every minute. Resolves to the chosen
/// time, or null when the sheet was closed without *Fertig*.
///
/// [use24Hour] overrides the device's choice where the value is written in 24-hour
/// form whatever the device says (the settings).
Future<TimeOfDay?> showTimeWheel(
  BuildContext context, {
  required TimeOfDay initial,
  String? title,
  bool? use24Hour,
}) {
  final twentyFour = use24Hour ?? clockIs24Hour(context);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _TimeWheelSheet(initial: initial, title: title, use24Hour: twentyFour),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({
    required this.initial,
    required this.title,
    required this.use24Hour,
  });

  final TimeOfDay initial;
  final String? title;
  final bool use24Hour;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  late bool _exact = _minute % timeWheelStep != 0;

  late final _hourWheel = FixedExtentScrollController(
    initialItem: widget.use24Hour ? _hour : _hour % 12,
  );
  late var _minuteWheel = FixedExtentScrollController(
    initialItem: _minuteIndex,
  );
  late final _periodWheel = FixedExtentScrollController(
    initialItem: _hour < 12 ? 0 : 1,
  );
  final _hourFocus = FocusNode(debugLabel: 'time-wheel-hour');
  final _minuteFocus = FocusNode(debugLabel: 'time-wheel-minute');

  int get _minuteCount => _exact ? 60 : 60 ~/ timeWheelStep;
  int get _minuteIndex => _exact ? _minute : _minute ~/ timeWheelStep;
  int get _hourCount => widget.use24Hour ? 24 : 12;

  @override
  void dispose() {
    _hourWheel.dispose();
    _minuteWheel.dispose();
    _periodWheel.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _done() =>
      Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute));

  /// The hour wheel stopped on [index] (any integer: the wheel goes round).
  void _hourChanged(int index) {
    final value = index % _hourCount;
    setState(() {
      _hour = widget.use24Hour ? value : value + (_hour < 12 ? 0 : 12);
    });
  }

  void _minuteChanged(int index) {
    final value = index % _minuteCount;
    setState(() => _minute = _exact ? value : value * timeWheelStep);
  }

  void _periodChanged(int index) {
    setState(() => _hour = _hour % 12 + (index == 0 ? 0 : 12));
  }

  /// Every minute, or steps of five again (the minute then goes to the nearest step).
  void _setExact(bool exact) {
    if (exact == _exact) return;
    _showMinutes(
      exact: exact,
      minute: exact
          ? _minute
          : (_minute / timeWheelStep).round() * timeWheelStep % 60,
    );
  }

  /// A minute wheel of its own for [exact], standing on [minute].
  void _showMinutes({required bool exact, required int minute}) {
    final old = _minuteWheel;
    setState(() {
      _exact = exact;
      _minute = minute;
      _minuteWheel = FixedExtentScrollController(initialItem: _minuteIndex);
    });
    // The old wheel is still attached until this frame has replaced it.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Turns [wheel] by [delta] items, the short way when [delta] is a distance.
  void _turn(FixedExtentScrollController wheel, int delta) {
    if (delta == 0 || !wheel.hasClients) return;
    final target = wheel.selectedItem + delta;
    if (motionAllowed(context)) {
      unawaited(
        wheel.animateToItem(
          target,
          duration: Tokens.motionStandard,
          curve: Curves.easeOut,
        ),
      );
    } else {
      wheel.jumpToItem(target);
    }
  }

  /// Turns [wheel] of [count] items to [index] by the shorter way round.
  void _turnTo(FixedExtentScrollController wheel, int count, int index) {
    if (!wheel.hasClients) return;
    var delta = (index - wheel.selectedItem) % count;
    if (delta > count ~/ 2) delta -= count;
    _turn(wheel, delta);
  }

  void _typedHour(int value) {
    if (widget.use24Hour) {
      _turnTo(_hourWheel, 24, value);
    } else if (value >= 1 && value <= 12) {
      _turnTo(_hourWheel, 12, value % 12);
    }
  }

  void _typedMinute(int value) {
    final exact = _exact || value % timeWheelStep != 0;
    if (exact == _exact && _minuteWheel.hasClients) {
      _turnTo(
        _minuteWheel,
        _minuteCount,
        _exact ? value : value ~/ timeWheelStep,
      );
    } else {
      // The step changes, or the wheel was replaced a moment ago and is not on the
      // screen yet (two digits typed fast): one that opens on the minute.
      _showMinutes(exact: exact, minute: value);
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// The hour as its wheel writes it: "0"–"23", or "12", "1"–"11".
  String _hourText(int index) {
    if (widget.use24Hour) return '$index';
    return '${index == 0 ? 12 : index}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final media = MediaQuery.of(context);
    final digits = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // A row is as tall as its (scaled) number needs, never less than a touch target;
    // five rows show unless the screen is too short for them (a phone on its side).
    final extent = math.max(
      44.0,
      media.textScaler.scale(digits.fontSize!) * 1.5,
    );
    final rows = media.size.height - media.viewInsets.bottom < extent * 5 + 260
        ? 3
        : 5;
    final wheelWidth = math.max(
      72.0,
      media.textScaler.scale(digits.fontSize!) * 3,
    );
    final periods = [
      material.anteMeridiemAbbreviation,
      material.postMeridiemAbbreviation,
    ];

    Widget wheel({
      required Key key,
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int index) text,
      required ValueChanged<int> onChanged,
      required String label,
      required String value,
      FocusNode? focus,
      int? typedMax,
      ValueChanged<int>? onTyped,
      FocusNode? next,
      bool looping = true,
      bool autofocus = false,
    }) => Flexible(
      child: _Wheel(
        key: key,
        controller: controller,
        count: count,
        text: text,
        onChanged: onChanged,
        label: label,
        value: value,
        focusNode: focus,
        typedMax: typedMax,
        onTyped: onTyped,
        next: next,
        looping: looping,
        autofocus: autofocus,
        extent: extent,
        width: wheelWidth,
        style: digits,
        onStep: (delta) => _turn(controller, delta),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _done,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _done,
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          0,
          Tokens.space4,
          Tokens.space4,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  widget.title ?? l10n.timeWheelTitle,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Tokens.space2),
              SizedBox(
                height: extent * rows,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // One band behind all wheels marks the chosen row.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        height: extent,
                        width:
                            wheelWidth * (widget.use24Hour ? 2 : 3) +
                            Tokens.space8,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        wheel(
                          key: const ValueKey('time-wheel-hour'),
                          controller: _hourWheel,
                          count: _hourCount,
                          text: _hourText,
                          onChanged: _hourChanged,
                          label: l10n.timeWheelHour,
                          value: _hourText(
                            widget.use24Hour ? _hour : _hour % 12,
                          ),
                          focus: _hourFocus,
                          autofocus: true,
                          typedMax: widget.use24Hour ? 23 : 12,
                          onTyped: _typedHour,
                          next: _minuteFocus,
                        ),
                        ExcludeSemantics(child: Text(':', style: digits)),
                        wheel(
                          key: const ValueKey('time-wheel-minute'),
                          controller: _minuteWheel,
                          count: _minuteCount,
                          text: (i) => _two(_exact ? i : i * timeWheelStep),
                          onChanged: _minuteChanged,
                          label: l10n.timeWheelMinute,
                          value: _two(_minute),
                          focus: _minuteFocus,
                          typedMax: 59,
                          onTyped: _typedMinute,
                        ),
                        if (!widget.use24Hour)
                          wheel(
                            key: const ValueKey('time-wheel-period'),
                            controller: _periodWheel,
                            count: 2,
                            text: (i) => periods[i],
                            onChanged: _periodChanged,
                            label: l10n.timeWheelPeriod,
                            value: periods[_hour < 12 ? 0 : 1],
                            looping: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space2),
              FilterChip(
                key: const ValueKey('time-wheel-exact'),
                label: Text(l10n.timeWheelExact),
                selected: _exact,
                onSelected: _setExact,
              ),
              const SizedBox(height: Tokens.space3),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: Tokens.space2,
                overflowSpacing: Tokens.space2,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    key: const ValueKey('time-wheel-done'),
                    onPressed: _done,
                    child: Text(l10n.timeWheelDone),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One wheel. To a screen reader it is a single adjustable value ("Stunde, 14"), as
/// the platforms' own pickers are; with a keyboard the arrows step and digits jump.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.text,
    required this.onChanged,
    required this.onStep,
    required this.label,
    required this.value,
    required this.extent,
    required this.width,
    required this.style,
    required this.looping,
    this.focusNode,
    this.autofocus = false,
    this.typedMax,
    this.onTyped,
    this.next,
    super.key,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) text;
  final ValueChanged<int> onChanged;

  /// Turn by so many items (±1 from the arrow keys and the screen reader).
  final ValueChanged<int> onStep;
  final String label;
  final String value;
  final double extent;
  final double width;
  final TextStyle style;
  final bool looping;
  final FocusNode? focusNode;

  /// Whether the keyboard starts here (the hours), so a time can be typed at once.
  final bool autofocus;

  /// The largest number that can be typed; null takes no digits.
  final int? typedMax;
  final ValueChanged<int>? onTyped;

  /// Where the focus goes once the typed number is complete.
  final FocusNode? next;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  /// What has been typed so far, and when: a pause starts a new number.
  int _typed = 0;
  DateTime _typedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onStep(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onStep(1);
      return KeyEventResult.handled;
    }
    final max = widget.typedMax;
    final digit = int.tryParse(event.character ?? '');
    if (max == null || digit == null || event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    final fresh = now.difference(_typedAt) > const Duration(milliseconds: 1500);
    var value = fresh ? digit : _typed * 10 + digit;
    if (value > max) value = digit;
    _typed = value;
    _typedAt = now;
    widget.onTyped?.call(value);
    // No further digit fits: the number is complete.
    if (value * 10 > max) {
      _typed = 0;
      _typedAt = DateTime.fromMillisecondsSinceEpoch(0);
      widget.next?.requestFocus();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = widget.controller.hasClients
        ? widget.controller.selectedItem
        : widget.controller.initialItem;
    String at(int index) => widget.looping
        ? widget.text(index % widget.count)
        : widget.text(index.clamp(0, widget.count - 1));
    return Semantics(
      container: true,
      label: widget.label,
      value: widget.value,
      increasedValue: at(current + 1),
      decreasedValue: at(current - 1),
      onIncrease: () => widget.onStep(1),
      onDecrease: () => widget.onStep(-1),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // Only for a keyboard: a finger needs no ring around the hours.
              border:
                  _focused &&
                      FocusManager.instance.highlightMode ==
                          FocusHighlightMode.traditional
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: SizedBox(
              width: widget.width,
              // A mouse drags the wheel too, and no desktop scrollbar is drawn on it.
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                  scrollbars: false,
                ),
                child: CupertinoPicker(
                  // A new picker when the step changes (its items are others, on a
                  // controller of their own); the focus and what was typed stay.
                  key: ObjectKey(widget.controller),
                  scrollController: widget.controller,
                  itemExtent: widget.extent,
                  looping: widget.looping,
                  // The sheet draws one band for all wheels.
                  selectionOverlay: null,
                  onSelectedItemChanged: widget.onChanged,
                  children: [
                    for (var i = 0; i < widget.count; i++)
                      Center(
                        child: Text(
                          widget.text(i),
                          style: widget.style,
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
