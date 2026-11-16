import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/time_wheel.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// One date, and optionally a time of day, of an entry: tap the date to choose it, tap the
/// time to choose it with the time wheel. A time needs its date, so the time is greyed
/// out until there is one, and removing the date takes the time with it.
class TripDateField extends StatelessWidget {
  const TripDateField({
    required this.label,
    required this.date,
    required this.onDate,
    this.time,
    this.onTime,
    this.withTime = true,
    this.pickerStart,
    this.fieldKey,
    super.key,
  });

  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final ValueChanged<DateTime?> onDate;
  final ValueChanged<TimeOfDay?>? onTime;

  /// False for a date without a time (the last day of free cancellation).
  final bool withTime;

  /// Where the date picker opens when there is no date yet.
  final DateTime? pickerStart;

  /// Prefix of the keys of the date and time controls: `<key>-date`, `<key>-time`.
  final String? fieldKey;

  Future<void> _pickDate(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = date ?? pickerStart ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 8),
    );
    if (picked != null) onDate(DateUtils.dateOnly(picked));
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimeWheel(
      context,
      initial: time ?? const TimeOfDay(hour: 12, minute: 0),
      title: label,
    );
    if (picked != null) onTime?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateField = _Pick(
      key: fieldKey == null ? null : ValueKey('$fieldKey-date'),
      label: label,
      value: date == null ? null : formatTripDay(context, date!),
      empty: l10n.tripEntryAddDate,
      clearTooltip: l10n.tripEntryClearDate,
      onTap: () => _pickDate(context),
      onClear: date == null ? null : () => onDate(null),
    );
    if (!withTime) return dateField;
    final timeField = _Pick(
      key: fieldKey == null ? null : ValueKey('$fieldKey-time'),
      label: l10n.timeWheelTitle,
      value: time == null ? null : formatTripTime(context, time!),
      empty: l10n.tripEntryAddTime,
      clearTooltip: l10n.tripEntryClearTime,
      onTap: date == null ? null : () => _pickTime(context),
      onClear: time == null ? null : () => onTime?.call(null),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: dateField),
        const SizedBox(width: Tokens.space2),
        Expanded(flex: 2, child: timeField),
      ],
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.value,
    required this.empty,
    required this.clearTooltip,
    required this.onTap,
    required this.onClear,
    super.key,
  });

  final String label;
  final String? value;
  final String empty;
  final String clearTooltip;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.space2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            suffixIcon: onClear == null
                ? null
                : IconButton(
                    tooltip: clearTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
          ),
          child: Text(
            value ?? empty,
            style: value == null
                ? TextStyle(color: scheme.onSurfaceVariant)
                : null,
          ),
        ),
      ),
    );
  }
}
