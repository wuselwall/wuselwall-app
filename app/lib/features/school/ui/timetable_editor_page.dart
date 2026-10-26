import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';

/// What the editor opens on: a child and a term (specs/15 "Maintaining it").
class TimetableEditArgs {
  const TimetableEditArgs({required this.profileId, required this.termId});

  final String profileId;
  final String termId;
}

/// The grid entry of spec 15: a cell per weekday and Stunde, the whole timetable saved
/// at once with `timetable_lessons_set`. Guardian only (the server decides).
class TimetableEditorPage extends ConsumerStatefulWidget {
  const TimetableEditorPage({required this.args, super.key});

  final TimetableEditArgs? args;

  @override
  ConsumerState<TimetableEditorPage> createState() =>
      _TimetableEditorPageState();
}

class _TimetableEditorPageState extends ConsumerState<TimetableEditorPage> {
  /// Bumped after a copy, so the body reads the copied timetable afresh.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final args = widget.args;
    final data = ref.watch(schoolDataProvider);
    final title = args == null
        ? l10n.schoolEditTimetable
        : _title(context, data, args);
    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(l10n.comingSoon)),
      );
    }
    return data.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(schoolDataProvider),
        ),
      ),
      data: (d) => _EditorBody(
        key: ValueKey(_generation),
        title: title,
        data: d,
        args: args,
        onCopied: () async {
          ref.invalidate(schoolDataProvider);
          await ref.read(schoolDataProvider.future);
          if (mounted) setState(() => _generation++);
        },
      ),
    );
  }

  String _title(
    BuildContext context,
    AsyncValue<SchoolData> data,
    TimetableEditArgs a,
  ) {
    final name =
        ref
            .watch(membersProvider)
            .value
            ?.where((m) => m.id == a.profileId)
            .firstOrNull
            ?.displayName ??
        '';
    return context.l10n.boardTimetableTitle(name);
  }
}

/// One cell's entry. [parity] is 'all', 'a' or 'b'.
class _Draft {
  _Draft({
    required this.weekday,
    required this.period,
    required this.parity,
    this.subjectId,
    this.room,
    this.teacher,
    this.isNotable,
  });

  final int weekday;
  final int period;
  String parity;
  String? subjectId;
  String? room;
  String? teacher;

  /// Kept from the saved row; null lets the server take the subject's default.
  bool? isNotable;

  String get key => '$weekday:$period:$parity';

  /// The same entry on another weekday; period, parity and subject are kept.
  _Draft copyTo(int otherWeekday) => _Draft(
    weekday: otherWeekday,
    period: period,
    parity: parity,
    subjectId: subjectId,
    room: room,
    teacher: teacher,
    isNotable: isNotable,
  );

  LessonRecord toRecord(String timetableId) => LessonRecord(
    id: '',
    timetableId: timetableId,
    weekday: weekday,
    periodIndex: period,
    subjectId: subjectId,
    teacher: teacher,
    room: room,
    weekParity: parity,
    isNotable: isNotable,
  );
}

/// A care row (Hort, a club): a name, its times, and the weekdays it happens on.
class _CareBlock {
  _CareBlock({
    required this.title,
    required this.starts,
    required this.ends,
    required this.days,
  });

  String title;
  TimeOfDay starts;
  TimeOfDay ends;
  final Set<int> days;

  _CareBlock copy() =>
      _CareBlock(title: title, starts: starts, ends: ends, days: {...days});
}

/// The grid before a day operation, for its Undo.
class _GridSnapshot {
  const _GridSnapshot({required this.cells, required this.care});

  final Map<String, _Draft> cells;
  final List<_CareBlock> care;
}

/// The weekday menu of a day header.
enum _DayAction { clear, copy, swap }

/// Monday 2 January 2023 is a Monday: a date for each weekday name (1 = Monday).
DateTime _weekdayDate(int weekday) =>
    DateTime(2023, 1, 2).add(Duration(days: weekday - 1));

/// The lessons the server takes for a whole grid: the Stunden cells, then the care rows
/// on their weekdays.
List<LessonRecord> _gridLessons(
  String timetableId,
  Iterable<_Draft> drafts,
  List<_CareBlock> care,
) => [
  for (final d in drafts) d.toRecord(timetableId),
  for (final b in care)
    for (final day in b.days.toList()..sort())
      LessonRecord(
        id: '',
        timetableId: timetableId,
        weekday: day,
        kind: 'care',
        title: b.title.trim().isEmpty ? null : b.title.trim(),
        startsAt: b.starts,
        endsAt: b.ends,
      ),
];

/// Which weekdays a day is copied to: any of the others, several at once.
class _CopyDayDialog extends StatefulWidget {
  const _CopyDayDialog({required this.from});

  final int from;

  @override
  State<_CopyDayDialog> createState() => _CopyDayDialogState();
}

class _CopyDayDialogState extends State<_CopyDayDialog> {
  final _targets = <int>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        l10n.schoolsUiCopyDayTitle(
          context.weekdayLong(_weekdayDate(widget.from)),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in const [1, 2, 3, 4, 5])
            if (d != widget.from)
              CheckboxListTile(
                key: ValueKey('copy-target-$d'),
                value: _targets.contains(d),
                title: Text(context.weekdayLong(_weekdayDate(d))),
                onChanged: (v) => setState(
                  () => v == true ? _targets.add(d) : _targets.remove(d),
                ),
              ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _targets.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<int>.of(_targets)),
          child: Text(l10n.schoolsUiCopyDayApply),
        ),
      ],
    );
  }
}

class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({
    required this.title,
    required this.data,
    required this.args,
    required this.onCopied,
    super.key,
  });

  final String title;
  final SchoolData data;
  final TimetableEditArgs args;
  final Future<void> Function() onCopied;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  late TimetableRecord? _timetable = widget.data.timetableOf(
    widget.args.profileId,
    widget.args.termId,
  );
  late final TermRecord? _term = widget.data.terms
      .where((t) => t.id == widget.args.termId)
      .firstOrNull;

  /// The school of the term the timetable is entered for. Never a guess: with several
  /// schools the term decides, and a term-less editor has no school.
  late final String? _schoolId = _term?.schoolId ?? _timetable?.schoolId;
  late final SchoolRecord? _school = widget.data.schools
      .where((s) => s.id == _schoolId)
      .firstOrNull;
  late final TextEditingController _class = TextEditingController(
    text: _timetable?.classLabel ?? '',
  );
  late String _cycle = _timetable?.weekCycle ?? 'weekly';
  late final Map<String, _Draft> _cells = {
    for (final l in widget.data.lessons)
      if (l.timetableId == _timetable?.id &&
          l.kind == 'lesson' &&
          l.periodIndex != null)
        _key(l): _Draft(
          weekday: l.weekday,
          period: l.periodIndex!,
          parity: l.weekParity,
          subjectId: l.subjectId,
          room: l.room,
          teacher: l.teacher,
          isNotable: l.isNotable,
        ),
  };
  late final List<_CareBlock> _care = _careFromLessons();
  bool _busy = false;

  /// Subjects created from a cell while editing (specs/24 "Fewer required facts"),
  /// until the refetched data carries them.
  final List<SubjectRecord> _created = [];

  static String _key(LessonRecord l) =>
      '${l.weekday}:${l.periodIndex}:${l.weekParity}';

  List<_CareBlock> _careFromLessons() {
    final blocks = <String, _CareBlock>{};
    for (final l in widget.data.lessons) {
      if (l.timetableId != _timetable?.id || l.periodIndex != null) continue;
      if (l.startsAt == null || l.endsAt == null) continue;
      final title = l.title ?? '';
      final id = '$title|${l.startsAt}|${l.endsAt}';
      blocks
          .putIfAbsent(
            id,
            () => _CareBlock(
              title: title,
              starts: l.startsAt!,
              ends: l.endsAt!,
              days: {},
            ),
          )
          .days
          .add(l.weekday);
    }
    return blocks.values.toList();
  }

  @override
  void dispose() {
    _class.dispose();
    super.dispose();
  }

  List<SubjectRecord> get _subjects {
    final ids = {for (final s in widget.data.subjects) s.id};
    return [
      ...widget.data.subjects,
      for (final s in _created)
        if (!ids.contains(s.id)) s,
    ];
  }

  /// Creates a subject named as typed in the cell: name and short name from the text,
  /// the least used tint. Returns it with its id, or null when the server refused.
  Future<SubjectRecord?> _createSubject(String text) async {
    final name = text.trim();
    final record = SubjectRecord(
      id: '',
      name: name,
      shortName: name.length <= 12 ? name : name.substring(0, 12),
      tint: nextSubjectTint(_subjects, 0),
    );
    final result = await ref
        .read(schoolRepositoryProvider)
        .saveSubject(actor: ref.read(actingProfileProvider), subject: record);
    if (!mounted) return null;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
        return null;
      case Ok(:final value):
        final created = SubjectRecord(
          id: value,
          name: record.name,
          shortName: record.shortName,
          tint: record.tint,
        );
        setState(() => _created.add(created));
        ref.invalidate(schoolDataProvider);
        return created;
    }
  }

  SubjectRecord? _subjectOf(String? id) =>
      _subjects.where((s) => s.id == id).firstOrNull;

  /// The grid as it stands, copied, for the Undo of a day operation.
  _GridSnapshot _snapshot() => _GridSnapshot(
    cells: {
      for (final e in _cells.entries) e.key: e.value.copyTo(e.value.weekday),
    },
    care: [for (final b in _care) b.copy()],
  );

  void _restore(_GridSnapshot s) {
    _cells
      ..clear()
      ..addAll({
        for (final e in s.cells.entries) e.key: e.value.copyTo(e.value.weekday),
      });
    for (var i = 0; i < _care.length; i++) {
      _care[i].days
        ..clear()
        ..addAll(s.care[i].days);
    }
  }

  void _onDayAction(int weekday, _DayAction action) {
    final l10n = context.l10n;
    switch (action) {
      case _DayAction.clear:
        _changeGrid(
          message: l10n.schoolsUiDayCleared,
          change: () {
            _cells.removeWhere((_, d) => d.weekday == weekday);
            for (final b in _care) {
              b.days.remove(weekday);
            }
          },
        );
      case _DayAction.copy:
        unawaited(_pickCopyTargets(weekday));
      case _DayAction.swap:
        unawaited(_pickSwapTarget(weekday));
    }
  }

  Future<void> _pickCopyTargets(int from) async {
    final targets = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _CopyDayDialog(from: from),
    );
    if (targets == null || targets.isEmpty || !mounted) return;
    _changeGrid(
      message: context.l10n.schoolsUiDayCopied,
      change: () {
        final sources = [
          for (final d in _cells.values)
            if (d.weekday == from) d,
        ];
        _cells.removeWhere((_, d) => targets.contains(d.weekday));
        for (final t in targets) {
          for (final s in sources) {
            final copy = s.copyTo(t);
            _cells[copy.key] = copy;
          }
        }
        for (final b in _care) {
          final had = b.days.contains(from);
          b.days.removeAll(targets);
          if (had) b.days.addAll(targets);
        }
      },
    );
  }

  Future<void> _pickSwapTarget(int from) async {
    final other = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          dialogContext.l10n.schoolsUiSwapDayTitle(
            dialogContext.weekdayLong(_weekdayDate(from)),
          ),
        ),
        children: [
          for (final d in const [1, 2, 3, 4, 5])
            if (d != from)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(d),
                child: Text(dialogContext.weekdayLong(_weekdayDate(d))),
              ),
        ],
      ),
    );
    if (other == null || !mounted) return;
    _changeGrid(
      message: context.l10n.schoolsUiDaySwapped,
      change: () {
        final moved = [
          for (final d in _cells.values)
            if (d.weekday == from || d.weekday == other)
              d.copyTo(d.weekday == from ? other : from),
        ];
        _cells.removeWhere((_, d) => d.weekday == from || d.weekday == other);
        for (final m in moved) {
          _cells[m.key] = m;
        }
        for (final b in _care) {
          final hadFrom = b.days.contains(from);
          final hadOther = b.days.contains(other);
          b.days
            ..remove(from)
            ..remove(other);
          if (hadFrom) b.days.add(other);
          if (hadOther) b.days.add(from);
        }
      },
    );
  }

  /// Applies a day operation to the draft, like any other edit: nothing is saved until
  /// Save. Undo restores the draft as it was before the operation.
  void _changeGrid({required String message, required void Function() change}) {
    final l10n = context.l10n;
    final before = _snapshot();
    setState(change);
    context.showMessageWithAction(
      message,
      actionLabel: l10n.schoolsUiUndo,
      onAction: () {
        if (mounted) setState(() => _restore(before));
      },
    );
  }

  Future<void> _editCell(int weekday, int period) async {
    final ab = _cycle == 'ab';
    final result = await showDialog<_CellResult>(
      context: context,
      builder: (_) => _CellDialog(
        subjects: _subjects,
        abMode: ab,
        weekday: weekday,
        period: period,
        existing: {
          for (final p in const ['all', 'a', 'b'])
            p: _cells['$weekday:$period:$p'],
        },
        onCreateSubject: _createSubject,
      ),
    );
    if (result == null) return;
    setState(() {
      for (final p in result.clearParities) {
        _cells.remove('$weekday:$period:$p');
      }
      final draft = result.draft;
      if (draft != null) {
        _cells.remove('$weekday:$period:${draft.parity}');
        _cells[draft.key] = draft;
      }
    });
  }

  void _clearCell(int weekday, int period) => setState(
    () => _cells.removeWhere(
      (_, d) => d.weekday == weekday && d.period == period,
    ),
  );

  Future<void> _save() async {
    final schoolId = _schoolId;
    if (schoolId == null) return;
    final actor = ref.read(actingProfileProvider);
    final repo = ref.read(schoolRepositoryProvider);
    setState(() => _busy = true);

    var timetableId = _timetable?.id;
    final meta = TimetableRecord(
      id: _timetable?.id ?? '',
      profileId: widget.args.profileId,
      schoolId: schoolId,
      termId: widget.args.termId,
      classLabel: _class.text.trim().isEmpty ? null : _class.text.trim(),
      weekCycle: _cycle,
      validFrom: _term?.startsOn ?? DateTime.now(),
    );
    final metaChanged =
        _timetable == null ||
        _timetable?.classLabel != meta.classLabel ||
        _timetable?.weekCycle != meta.weekCycle;
    if (metaChanged) {
      final saved = await repo.saveTimetable(actor: actor, timetable: meta);
      if (!mounted) return;
      if (saved case Err(:final failure)) {
        setState(() => _busy = false);
        context.showFailure(failure);
        return;
      }
      timetableId = saved.valueOrNull;
      // Retain the created identity, also when saving lessons fails and is retried.
      _timetable = TimetableRecord(
        id: timetableId!,
        profileId: meta.profileId,
        schoolId: meta.schoolId,
        termId: meta.termId,
        classLabel: meta.classLabel,
        weekCycle: meta.weekCycle,
        validFrom: meta.validFrom,
        validTo: meta.validTo,
      );
    }

    final result = await repo.setLessons(
      actor: actor,
      timetableId: timetableId!,
      lessons: _gridLessons(timetableId, _cells.values, _care),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok():
        ref
          ..invalidate(schoolDataProvider)
          ..invalidate(schoolWeekProvider);
        context.showMessage(context.l10n.schoolSaved);
    }
  }

  Future<void> _copy() async {
    final l10n = context.l10n;
    final others = widget.data.timetables
        .where((t) => t.id != _timetable?.id)
        .toList();
    final from = await showDialog<TimetableRecord>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l10n.schoolCopyPick),
        children: [
          for (final t in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(t),
              child: Text(_label(t)),
            ),
        ],
      ),
    );
    if (from == null || !mounted) return;
    final result = await ref
        .read(schoolRepositoryProvider)
        .copyTimetable(
          actor: ref.read(actingProfileProvider),
          fromTimetableId: from.id,
          profileId: widget.args.profileId,
          termId: widget.args.termId,
        );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok():
        await widget.onCopied();
    }
  }

  String _label(TimetableRecord t) {
    final name =
        ref
            .read(membersProvider)
            .value
            ?.where((m) => m.id == t.profileId)
            .firstOrNull
            ?.displayName ??
        '';
    final term = widget.data.terms.where((x) => x.id == t.termId).firstOrNull;
    return [
      name,
      if (term != null) term.name,
      if (t.classLabel != null) t.classLabel!,
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final periods = [
      for (final p in widget.data.periods.where((p) => p.schoolId == _schoolId))
        p,
    ]..sort((a, b) => minutesOf(a.starts).compareTo(minutesOf(b.starts)));
    final days = [1, 2, 3, 4, 5];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_school case final school?) ...[
            Text(
              l10n.schoolsUiSchoolOf(school.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],
          if (_term case final term?) ...[
            Text(
              '${l10n.schoolTermEdit}: ${term.name} · '
              '${context.dayMonth(term.startsOn)} ${term.startsOn.year} – '
              '${context.dayMonth(term.endsOn)} ${term.endsOn.year}',
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _class,
            decoration: InputDecoration(labelText: l10n.schoolEditorClass),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'weekly',
                label: Text(l10n.schoolCycleWeekly),
              ),
              ButtonSegment(value: 'ab', label: Text(l10n.schoolCycleAb)),
            ],
            selected: {_cycle},
            onSelectionChanged: (s) => setState(() => _cycle = s.first),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.content_copy_outlined),
              label: Text(l10n.schoolCopyFrom),
            ),
          ),
          if (widget.data.subjects.isEmpty) Text(l10n.schoolNoSubjects),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Five readable, tappable day columns scroll on narrow screens.
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final gridWidth = math.max(
                constraints.maxWidth,
                84 + days.length * 120 * textScale,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      _Header(
                        days: days,
                        onDayAction: _onDayAction,
                        labelWidth: 84,
                      ),
                      for (final p in periods)
                        if (p.isBreak)
                          const SizedBox(height: 6)
                        else
                          _Row(
                            label:
                                '${p.index}. · ${context.span(p.starts, p.ends)}',
                            cells: [
                              for (final d in days)
                                _CellTile(
                                  weekday: d,
                                  period: p.index,
                                  drafts: [
                                    for (final parity in const [
                                      'all',
                                      'a',
                                      'b',
                                    ])
                                      if (_cells['$d:${p.index}:$parity'] !=
                                          null)
                                        _cells['$d:${p.index}:$parity']!,
                                  ],
                                  subjectOf: _subjectOf,
                                  onTap: () => _editCell(d, p.index),
                                  onClear: () => _clearCell(d, p.index),
                                ),
                            ],
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.schoolCareRows,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _care.length; i++)
            _CareCard(
              key: ObjectKey(_care[i]),
              block: _care[i],
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _care.removeAt(i)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(
                () => _care.add(
                  _CareBlock(
                    title: '',
                    starts: const TimeOfDay(hour: 13, minute: 0),
                    ends: const TimeOfDay(hour: 15, minute: 30),
                    days: {},
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.schoolAddCare),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(l10n.schoolSaveTimetable),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.days,
    required this.onDayAction,
    required this.labelWidth,
  });

  final List<int> days;
  final void Function(int weekday, _DayAction action) onDayAction;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        SizedBox(width: labelWidth),
        for (final d in days)
          Expanded(
            child: Column(
              children: [
                Text(
                  context.weekdayShort(_weekdayDate(d)),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                PopupMenuButton<_DayAction>(
                  tooltip: l10n.schoolsUiDayMenu,
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (a) => onDayAction(d, a),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _DayAction.clear,
                      child: Text(l10n.schoolClearDay),
                    ),
                    PopupMenuItem(
                      value: _DayAction.copy,
                      child: Text(l10n.schoolsUiCopyDay),
                    ),
                    PopupMenuItem(
                      value: _DayAction.swap,
                      child: Text(l10n.schoolsUiSwapDay),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.cells});

  final String label;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    // Cells take the height of the tallest, inside the scrolling list.
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, top: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          for (final c in cells) Expanded(child: c),
        ],
      ),
    ),
  );
}

/// One cell: focusable (Tab moves on, Enter edits, Delete clears), showing its
/// entries; in A/B weeks an A and a B line, each named.
class _CellTile extends StatelessWidget {
  const _CellTile({
    required this.weekday,
    required this.period,
    required this.drafts,
    required this.subjectOf,
    required this.onTap,
    required this.onClear,
  });

  final int weekday;
  final int period;
  final List<_Draft> drafts;
  final SubjectRecord? Function(String? id) subjectOf;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ww = context.ww;
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          onClear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          container: true,
          label: drafts.isEmpty
              ? context.l10n.schoolLessonActions(
                  context.l10n.schoolAddLesson,
                  context.weekdayLong(_weekdayDate(weekday)),
                  context.l10n.boardPeriod(period),
                )
              : null,
          child: InkWell(
            key: ValueKey('cell-$weekday-$period'),
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: ww.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final d in drafts)
                    Row(
                      children: [
                        if (d.parity != 'all')
                          Text(
                            d.parity.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        if (d.subjectId != null) ...[
                          Icon(
                            schoolIcon(subjectOf(d.subjectId)?.iconKey),
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Expanded(
                          child: Text(
                            subjectOf(d.subjectId)?.shortName ?? '—',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (d.room != null)
                          Text(
                            d.room!,
                            style: TextStyle(fontSize: 11, color: ww.ink2),
                          ),
                      ],
                    ),
                  if (drafts.isEmpty) const SizedBox(height: 34),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Result of the cell dialog: the entry to keep (or null) and the parities to clear.
class _CellResult {
  const _CellResult({this.draft, this.clearParities = const []});

  final _Draft? draft;
  final List<String> clearParities;
}

class _CellDialog extends StatefulWidget {
  const _CellDialog({
    required this.subjects,
    required this.abMode,
    required this.weekday,
    required this.period,
    required this.existing,
    required this.onCreateSubject,
  });

  final List<SubjectRecord> subjects;
  final bool abMode;
  final int weekday;
  final int period;
  final Map<String, _Draft?> existing;

  /// Creates the subject typed into the search and returns it, or null on failure.
  final Future<SubjectRecord?> Function(String name) onCreateSubject;

  @override
  State<_CellDialog> createState() => _CellDialogState();
}

class _CellDialogState extends State<_CellDialog> {
  late String _parity = widget.abMode
      ? (widget.existing['a'] != null ? 'a' : 'all')
      : 'all';
  String _filter = '';
  String? _subjectId;
  late final _room = TextEditingController();
  late final _teacher = TextEditingController();

  /// Subjects created from this dialog, shown with the rest.
  final List<SubjectRecord> _created = [];
  bool _creating = false;
  late final _search = TextEditingController();

  _Draft? get _current => widget.existing[_parity];

  List<SubjectRecord> get _all => [...widget.subjects, ..._created];

  Future<void> _create() async {
    final text = _filter.trim();
    if (text.isEmpty || _creating) return;
    setState(() => _creating = true);
    final created = await widget.onCreateSubject(text);
    if (!mounted) return;
    setState(() {
      _creating = false;
      if (created != null) {
        _created.add(created);
        _subjectId = created.id;
        _filter = '';
        _search.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final c = _current;
    _subjectId = c?.subjectId;
    _room.text = c?.room ?? '';
    _teacher.text = c?.teacher ?? '';
  }

  @override
  void dispose() {
    _room.dispose();
    _teacher.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _filter.trim().toLowerCase();
    final subjects = _all
        .where(
          (s) =>
              q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              s.shortName.toLowerCase().contains(q),
        )
        .toList();
    // Nothing matches what was typed exactly: offer to create it (specs/24).
    final folded = foldText(_filter);
    final canCreate =
        folded.isNotEmpty &&
        !_all.any(
          (s) => foldText(s.shortName) == folded || foldText(s.name) == folded,
        );
    return AlertDialog(
      title: Text(l10n.schoolPickSubject),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.abMode)
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'all',
                    label: Text(l10n.schoolParityAll),
                  ),
                  ButtonSegment(value: 'a', label: Text(l10n.schoolParityA)),
                  ButtonSegment(value: 'b', label: Text(l10n.schoolParityB)),
                ],
                selected: {_parity},
                onSelectionChanged: (s) => setState(() {
                  _parity = s.first;
                  _subjectId = _current?.subjectId;
                  _room.text = _current?.room ?? '';
                  _teacher.text = _current?.teacher ?? '';
                }),
              ),
            TextField(
              key: const ValueKey('cell-subject-search'),
              autofocus: true,
              controller: _search,
              decoration: InputDecoration(
                labelText: l10n.schoolSearchSubject,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _filter = v),
              onSubmitted: (_) {
                if (subjects.isEmpty && canCreate) _create();
              },
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
                    selected: _subjectId == s.id,
                    onSelected: (_) => setState(() => _subjectId = s.id),
                  ),
                if (canCreate)
                  ActionChip(
                    key: const ValueKey('cell-create-subject'),
                    avatar: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(l10n.schoolCreateSubject(_filter.trim())),
                    onPressed: _creating ? null : _create,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _room,
              decoration: InputDecoration(labelText: l10n.schoolRoom),
            ),
            TextField(
              controller: _teacher,
              decoration: InputDecoration(labelText: l10n.schoolTeacher),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_CellResult(clearParities: [_parity])),
          child: Text(l10n.schoolClearCell),
        ),
        FilledButton(
          onPressed: () {
            final room = _room.text.trim();
            final teacher = _teacher.text.trim();
            Navigator.of(context).pop(
              _CellResult(
                draft: _Draft(
                  weekday: widget.weekday,
                  period: widget.period,
                  parity: _parity,
                  subjectId: _subjectId,
                  room: room.isEmpty ? null : room,
                  teacher: teacher.isEmpty ? null : teacher,
                  isNotable: _current?.isNotable,
                ),
              ),
            );
          },
          child: Text(l10n.schoolApply),
        ),
      ],
    );
  }
}

/// A care row's editor: name, times, and the weekdays (Mo–Fr).
class _CareCard extends StatefulWidget {
  const _CareCard({
    required this.block,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final _CareBlock block;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_CareCard> createState() => _CareCardState();
}

class _CareCardState extends State<_CareCard> {
  late final _title = TextEditingController(text: widget.block.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _time({required bool start}) async {
    final b = widget.block;
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? b.starts : b.ends,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        b.starts = picked;
      } else {
        b.ends = picked;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = widget.block;
    final monday = DateTime(2023, 1, 2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: l10n.schoolCareTitle,
                    ),
                    onChanged: (v) {
                      b.title = v;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: l10n.schoolRemove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _time(start: true),
                  child: Text(context.time(b.starts)),
                ),
                const Text('–'),
                TextButton(
                  onPressed: () => _time(start: false),
                  child: Text(context.time(b.ends)),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 5; d++)
                  FilterChip(
                    label: Text(
                      context.weekdayShort(monday.add(Duration(days: d - 1))),
                    ),
                    selected: b.days.contains(d),
                    onSelected: (v) => setState(() {
                      if (v) {
                        b.days.add(d);
                      } else {
                        b.days.remove(d);
                      }
                      widget.onChanged();
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
