import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/region/ui/region_field.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/settings/ui/setting_labels.dart';
import 'package:wuselwall/features/wusel/ui/wusel_outfit_picker.dart';

/// One setting: title, the chip for default or customised, the explanation, the control
/// for its type, and reset when it differs from the default. Writes go to [onChanged]
/// with the JSON encoding of the type; the page decides who may write.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.entry,
    required this.onChanged,
    this.onReset,
    super.key,
  });

  final SettingEntry entry;
  final ValueChanged<Object?> onChanged;

  /// Null while the setting is at its default: there is nothing to reset.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = settingText(l10n, entry.key);
    return Padding(
      key: ValueKey('setting-${entry.key}'),
      padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(text.title, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: Tokens.space2),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  entry.isDefault
                      ? l10n.settingIsDefault
                      : l10n.settingIsCustom,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            text.help,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.space2),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _SettingControl(entry: entry, onChanged: onChanged),
                ),
              ),
              if (onReset != null)
                IconButton(
                  tooltip: l10n.settingReset,
                  icon: const Icon(Icons.settings_backup_restore),
                  onPressed: onReset,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingControl extends StatelessWidget {
  const _SettingControl({required this.entry, required this.onChanged});

  final SettingEntry entry;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = entry.value;
    // Wusel's outfit is chosen by looking at it (specs/25 "Outfits").
    if (entry.key == 'member.wusel_outfit') {
      return WuselOutfitPicker(
        selected: WuselOutfit.parse(value),
        onChanged: (o) => onChanged(o.name),
      );
    }
    return switch (entry.type) {
      SettingType.boolean => Switch(value: value == true, onChanged: onChanged),
      SettingType.integer => _NullableSwitch(
        entry: entry,
        onChanged: onChanged,
        child: value == null
            ? const SizedBox.shrink()
            : _IntegerStepper(
                entry: entry,
                value: (value as num).toInt(),
                onChanged: onChanged,
              ),
      ),
      SettingType.time => _NullableSwitch(
        entry: entry,
        onChanged: onChanged,
        child: value == null
            ? const SizedBox.shrink()
            : _TimeButton(time: value as String, onPicked: onChanged),
      ),
      SettingType.enumeration => _EnumChoice(
        entry: entry,
        onChanged: onChanged,
      ),
      SettingType.weekdayTime => _NullableSwitch(
        entry: entry,
        onChanged: onChanged,
        child: value == null
            ? const SizedBox.shrink()
            : _WeekdayTime(
                value: value as Map<String, dynamic>,
                onChanged: onChanged,
              ),
      ),
      SettingType.timeRange => _TimeRange(
        value: value! as Map<String, dynamic>,
        onChanged: onChanged,
      ),
      SettingType.times => _TimePair(
        value: value! as List<dynamic>,
        onChanged: onChanged,
      ),
      // The row's title already says "Region".
      SettingType.region => RegionField(
        code: value as String?,
        onChanged: onChanged,
        showLabel: false,
      ),
    };
  }
}

/// A nullable setting: a switch for on and off, and the control while it is on. Turning
/// it on writes the default if there is one, otherwise the control's own first value.
class _NullableSwitch extends StatelessWidget {
  const _NullableSwitch({
    required this.entry,
    required this.onChanged,
    required this.child,
  });

  final SettingEntry entry;
  final ValueChanged<Object?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final on = entry.value != null;
    if (!entry.nullable) return child;
    return Wrap(
      spacing: Tokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Switch(
          value: on,
          onChanged: (wanted) async {
            if (!wanted) {
              onChanged(null);
              return;
            }
            if (entry.defaultValue != null) {
              onChanged(entry.defaultValue);
              return;
            }
            if (entry.type == SettingType.integer) {
              onChanged(entry.min);
              return;
            }
            final picked = await pickSettingTime(context, '09:00');
            if (picked != null) onChanged(picked);
          },
        ),
        Text(on ? l10n.settingOn : l10n.settingOff),
        if (on) child,
      ],
    );
  }
}

class _IntegerStepper extends StatelessWidget {
  const _IntegerStepper({
    required this.entry,
    required this.value,
    required this.onChanged,
  });

  final SettingEntry entry;
  final int value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final min = entry.min ?? 0;
    final max = entry.max ?? 1 << 30;
    // Wide ranges (minutes, seconds) move in fives; narrow ones (points) by one.
    final step = max - min >= 60 ? 5 : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.settingDecrease,
          icon: const Icon(Icons.remove),
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max).toInt())
              : null,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: Text(
            settingIntegerLabel(l10n, entry.key, value),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        IconButton(
          tooltip: l10n.settingIncrease,
          icon: const Icon(Icons.add),
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max).toInt())
              : null,
        ),
      ],
    );
  }
}

/// The choice of an enum setting: one row of segments while every label fits its
/// segment on one line, otherwise a wrapping row of chips, so a label such as
/// "Automatisch" never breaks inside the word (specs/17, "Shape, depth and motion"). The same
/// test runs at every width and text scale.
class _EnumChoice extends StatelessWidget {
  const _EnumChoice({required this.entry, required this.onChanged});

  final SettingEntry entry;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = entry.value as String;
    final labels = {
      for (final v in entry.enumValues) v: settingValueLabel(l10n, v),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        if (segmentLabelsFit(context, labels.values, constraints.maxWidth)) {
          return SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final MapEntry(key: v, value: label) in labels.entries)
                ButtonSegment(value: v, label: Text(label, softWrap: false)),
            ],
            selected: {current},
            onSelectionChanged: (s) => onChanged(s.first),
          );
        }
        return Wrap(
          key: ValueKey('setting-choices-${entry.key}'),
          spacing: Tokens.space2,
          runSpacing: Tokens.space2,
          children: [
            for (final MapEntry(key: v, value: label) in labels.entries)
              ChoiceChip(
                label: Text(label),
                selected: v == current,
                showCheckmark: false,
                onSelected: (_) {
                  if (v != current) onChanged(v);
                },
              ),
          ],
        );
      },
    );
  }
}

/// Whether [labels] fit a [SegmentedButton] of [maxWidth] on one line each: the button
/// gives every segment the same width, so the widest label decides. Measured bold (the
/// selected segment) at the context's text scale, plus the segment's padding and border.
@visibleForTesting
bool segmentLabelsFit(
  BuildContext context,
  Iterable<String> labels,
  double maxWidth,
) {
  if (labels.isEmpty) return true;
  if (!maxWidth.isFinite) return true;
  final theme = Theme.of(context);
  final style =
      (theme.segmentedButtonTheme.style?.textStyle?.resolve({
                WidgetState.selected,
              }) ??
              theme.textTheme.labelLarge ??
              const TextStyle())
          .copyWith(fontWeight: FontWeight.w800);
  final scaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  // 12 px padding either side (the theme's), a 1 px border and a little slack.
  const chrome = 2 * 12 + 2 + 4;
  return widest + chrome <= maxWidth / labels.length;
}

class _WeekdayTime extends StatelessWidget {
  const _WeekdayTime({required this.value, required this.onChanged});

  /// `{weekday: 1-7 (Monday = 1), time: "HH:mm"}`.
  final Map<String, dynamic> value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final weekday = (value['weekday'] as num).toInt();
    final time = value['time'] as String;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Wrap(
      spacing: Tokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<int>(
          value: weekday,
          items: [
            // 4 January 2026 was a Sunday, so day n + 4 is ISO weekday n.
            for (var day = 1; day <= 7; day++)
              DropdownMenuItem(
                value: day,
                child: Text(
                  DateFormat.EEEE(locale).format(DateTime(2026, 1, 4 + day)),
                ),
              ),
          ],
          onChanged: (day) {
            if (day != null) onChanged({'weekday': day, 'time': time});
          },
        ),
        _TimeButton(
          time: time,
          onPicked: (picked) => onChanged({'weekday': weekday, 'time': picked}),
        ),
      ],
    );
  }
}

class _TimeRange extends StatelessWidget {
  const _TimeRange({required this.value, required this.onChanged});

  final Map<String, dynamic> value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final from = value['from'] as String;
    final to = value['to'] as String;
    return Wrap(
      spacing: Tokens.space2,
      runSpacing: Tokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.settingFrom),
        _TimeButton(
          time: from,
          onPicked: (picked) => onChanged({'from': picked, 'to': to}),
        ),
        Text(l10n.settingTo),
        _TimeButton(
          time: to,
          onPicked: (picked) => onChanged({'from': from, 'to': picked}),
        ),
      ],
    );
  }
}

/// Two ascending times (the day parts). An order that would not sort is refused here,
/// before anything is sent.
class _TimePair extends StatelessWidget {
  const _TimePair({required this.value, required this.onChanged});

  final List<dynamic> value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = value[0] as String;
    final second = value[1] as String;
    void write(List<String> times) {
      if (times[0].compareTo(times[1]) >= 0) {
        context.showMessage(l10n.errSettingInvalid);
        return;
      }
      onChanged(times);
    }

    return Wrap(
      spacing: Tokens.space2,
      runSpacing: Tokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.settingDayPartsMorningEnds),
        _TimeButton(time: first, onPicked: (picked) => write([picked, second])),
        Text(l10n.settingDayPartsEveningStarts),
        _TimeButton(time: second, onPicked: (picked) => write([first, picked])),
      ],
    );
  }
}

/// A button showing an "HH:mm" time in 24-hour form; tapping it opens the picker.
class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onPicked});

  final String time;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final tod = _parseTime(time);
    return OutlinedButton(
      onPressed: () async {
        final picked = await pickSettingTime(context, time);
        if (picked != null) onPicked(picked);
      },
      child: Text(
        MaterialLocalizations.of(context)
            .formatTimeOfDay(tod, alwaysUse24HourFormat: true),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// Opens the time picker in 24-hour form and returns the chosen "HH:mm", or null.
Future<String?> pickSettingTime(BuildContext context, String current) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: _parseTime(current),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}';
}

TimeOfDay _parseTime(String hhmm) => TimeOfDay(
  hour: int.parse(hhmm.substring(0, 2)),
  minute: int.parse(hhmm.substring(3, 5)),
);
