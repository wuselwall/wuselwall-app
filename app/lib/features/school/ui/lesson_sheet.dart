import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';

/// Opens the sheet for one lesson of one day: Fällt aus, Vertretung, Raum geändert,
/// and Zurücksetzen when an exception already exists. The server decides who may write
/// (guardians, or members when the household setting allows); its refusal is shown.
Future<void> showLessonSheet(
  BuildContext context, {
  required SchoolData data,
  required TimetableRecord timetable,
  required DateTime date,
  required Lesson lesson,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _LessonSheet(
    data: data,
    timetable: timetable,
    date: date,
    lesson: lesson,
  ),
);

enum _Mode { menu, substitute, room }

class _LessonSheet extends ConsumerStatefulWidget {
  const _LessonSheet({
    required this.data,
    required this.timetable,
    required this.date,
    required this.lesson,
  });

  final SchoolData data;
  final TimetableRecord timetable;
  final DateTime date;
  final Lesson lesson;

  @override
  ConsumerState<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends ConsumerState<_LessonSheet> {
  _Mode _mode = _Mode.menu;
  SubjectRecord? _subject;
  String _filter = '';
  final _teacher = TextEditingController();
  final _note = TextEditingController();
  final _room = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _teacher.dispose();
    _note.dispose();
    _room.dispose();
    super.dispose();
  }

  /// The exception this lesson already has on this date, if any.
  ExceptionRecord? get _existing => widget.data.exceptions
      .where(
        (e) =>
            e.timetableId == widget.timetable.id &&
            e.onDate == widget.date &&
            e.periodIndex == widget.lesson.period,
      )
      .firstOrNull;

  Future<void> _save(ExceptionRecord exception) async {
    setState(() => _busy = true);
    final result = await ref
        .read(schoolRepositoryProvider)
        .saveException(
          actor: ref.read(actingProfileProvider),
          exception: exception,
        );
    if (!mounted) return;
    if (result case Err(:final failure)) {
      setState(() => _busy = false);
      context.showFailure(failure);
      return;
    }
    ref
      ..invalidate(schoolDataProvider)
      ..invalidate(schoolWeekProvider);
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final existing = _existing;
    if (existing == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(schoolRepositoryProvider)
        .deleteException(
          actor: ref.read(actingProfileProvider),
          id: existing.id,
        );
    if (!mounted) return;
    if (result case Err(:final failure)) {
      setState(() => _busy = false);
      context.showFailure(failure);
      return;
    }
    ref
      ..invalidate(schoolDataProvider)
      ..invalidate(schoolWeekProvider);
    Navigator.of(context).pop();
  }

  ExceptionRecord _draft(String kind) => ExceptionRecord(
    id: _existing?.id ?? '',
    timetableId: widget.timetable.id,
    onDate: widget.date,
    periodIndex: widget.lesson.period,
    kind: kind,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lesson = widget.lesson;
    final day =
        '${context.weekdayLong(widget.date)}, ${context.dayMonth(widget.date)}';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    schoolIcon(widget.data.iconKeyFor(lesson.subject)),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.schoolLessonActions(
                        lesson.subject,
                        day,
                        l10n.boardPeriod(lesson.period ?? 0),
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                switch (_mode) {
                  _Mode.menu => _menu(context),
                  _Mode.substitute => _substitute(context),
                  _Mode.room => _roomForm(context),
                },
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonal(
          onPressed: () => _save(_draft('cancelled')),
          child: Text(l10n.schoolCancelLesson),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _mode = _Mode.substitute),
          child: Text(l10n.schoolSubstitute),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _mode = _Mode.room),
          child: Text(l10n.schoolRoomChange),
        ),
        if (_existing != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: _reset, child: Text(l10n.schoolResetException)),
        ],
      ],
    );
  }

  Widget _substitute(BuildContext context) {
    final l10n = context.l10n;
    final q = _filter.trim().toLowerCase();
    final subjects = widget.data.subjects
        .where(
          (s) =>
              q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              s.shortName.toLowerCase().contains(q),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: l10n.schoolSearchSubject,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in subjects)
              ChoiceChip(
                avatar: Icon(schoolIcon(s.iconKey), size: 18),
                label: Text(s.shortName),
                selected: _subject?.id == s.id,
                onSelected: (_) => setState(() => _subject = s),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _teacher,
          decoration: InputDecoration(labelText: l10n.schoolTeacher),
        ),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: l10n.schoolNote),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final draft = _draft('substituted');
            _save(
              ExceptionRecord(
                id: draft.id,
                timetableId: draft.timetableId,
                onDate: draft.onDate,
                periodIndex: draft.periodIndex,
                kind: 'substituted',
                subjectId: _subject?.id,
                teacher: _teacher.text.trim().isEmpty
                    ? null
                    : _teacher.text.trim(),
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: Text(l10n.schoolApply),
        ),
      ],
    );
  }

  Widget _roomForm(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _room,
          decoration: InputDecoration(labelText: l10n.schoolRoom),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final draft = _draft('room_change');
            _save(
              ExceptionRecord(
                id: draft.id,
                timetableId: draft.timetableId,
                onDate: draft.onDate,
                periodIndex: draft.periodIndex,
                kind: 'room_change',
                room: _room.text.trim().isEmpty ? null : _room.text.trim(),
              ),
            );
          },
          child: Text(l10n.schoolApply),
        ),
      ],
    );
  }
}
