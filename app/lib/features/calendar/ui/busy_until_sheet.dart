import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// "Termine bis 17:00" for one day (FR-1.19, specs/15). Opens for the acting member;
/// a guardian may pick any active member. Sets one day, the same time for Monday to
/// Friday of that week, or removes the day's time. A boundary, not an appointment, so
/// no event is made.
///
/// Public so the calendar's day header can open it.
Future<void> showBusyUntilSheet(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) async {
  final members = (await ref.read(membersProvider.future))
      .where((m) => m.active)
      .toList(growable: false);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BusyUntilSheet(date: dateOnly(date), members: members),
  );
}

class _BusyUntilSheet extends ConsumerStatefulWidget {
  const _BusyUntilSheet({required this.date, required this.members});

  final DateTime date;
  final List<Member> members;

  @override
  ConsumerState<_BusyUntilSheet> createState() => _BusyUntilSheetState();
}

class _BusyUntilSheetState extends ConsumerState<_BusyUntilSheet> {
  TimeOfDay? _until;
  bool _busy = false;
  late String? _profileId = _initialProfile();

  /// The acting member when they are in the list, else the first one.
  String? _initialProfile() {
    final acting = ref.read(actingProfileProvider);
    if (widget.members.any((m) => m.id == acting)) return acting;
    return widget.members.isEmpty ? null : widget.members.first.id;
  }

  bool get _actingIsGuardian {
    final acting = ref.read(actingProfileProvider);
    return widget.members.any((m) => m.id == acting && m.isGuardian);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _until ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null && mounted) setState(() => _until = picked);
  }

  /// Writes [days] with [until] (null removes). Stops at the first refusal and shows
  /// the server's message; the sheet closes only when every day was written.
  Future<void> _write(List<DateTime> days, TimeOfDay? until) async {
    final profileId = _profileId;
    if (profileId == null || _busy) return;
    final actor = ref.read(actingProfileProvider);
    if (profileId != actor && !await ensureGuardian(context, ref)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final repository = ref.read(calendarRepositoryProvider);
    for (final day in days) {
      final result = await repository.setBusyUntil(
        actor: actor,
        profileId: profileId,
        date: day,
        until: until,
      );
      if (!mounted) return;
      if (result case Err(:final failure)) {
        setState(() => _busy = false);
        context.showMessage(failure.message(context.l10n));
        return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final monday = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day - (widget.date.weekday - DateTime.monday),
    );
    final weekdays = [
      for (var i = 0; i < 5; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final theme = Theme.of(context);

    return SafeArea(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.busyTitle, style: theme.textTheme.titleLarge),
              Text(
                context.fullDate(widget.date),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Tokens.space2),
              Text(l10n.busyHelp, style: theme.textTheme.bodySmall),
              if (_actingIsGuardian && widget.members.length > 1) ...[
                const SizedBox(height: Tokens.space3),
                Text(l10n.busyFor, style: theme.textTheme.labelLarge),
                const SizedBox(height: Tokens.space1),
                Wrap(
                  spacing: Tokens.space2,
                  runSpacing: Tokens.space2,
                  children: [
                    for (final m in widget.members)
                      ChoiceChip(
                        avatar: MemberDot(
                          memberColor: m.color,
                          semanticLabel: m.displayName,
                          size: 16,
                        ),
                        label: Text(m.displayName),
                        selected: m.id == _profileId,
                        onSelected: (_) => setState(() => _profileId = m.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Tokens.space4),
              OutlinedButton.icon(
                onPressed: _busy || _profileId == null ? null : _pickTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  _until == null
                      ? l10n.busyPickTime
                      : l10n.boardBusyUntil(context.time(_until!)),
                ),
              ),
              const SizedBox(height: Tokens.space3),
              FilledButton(
                onPressed: _busy || _until == null
                    ? null
                    : () => _write([widget.date], _until),
                child: Text(l10n.busyThisDay),
              ),
              const SizedBox(height: Tokens.space2),
              OutlinedButton(
                onPressed: _busy || _until == null
                    ? null
                    : () => _write(weekdays, _until),
                child: Text(l10n.busyWholeWeek),
              ),
              const SizedBox(height: Tokens.space2),
              TextButton.icon(
                onPressed: _busy || _profileId == null
                    ? null
                    : () => _write([widget.date], null),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.busyRemove),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
