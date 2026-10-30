import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';

/// What the import preview opens on: a parsed payload from text or a photo (specs/24).
class TimetableImportArgs {
  const TimetableImportArgs({
    required this.import,
    this.profileId,
    this.unplaced = 0,
  });

  final TimetableImport import;

  /// The child to preselect; else the one the payload names, else the first.
  final String? profileId;

  /// From a scan: text pieces that fit no cell, so the parent knows to check.
  final int unplaced;
}

/// The preview before anything is written (specs/24 "The preview"): the child, the
/// school, the term it will land in, the grid as it will look, the subjects that will be
/// created, and every warning. Nothing exists until Übernehmen.
/// Guardian only (the server decides).
class TimetableImportPage extends ConsumerStatefulWidget {
  const TimetableImportPage({required this.args, super.key});

  final TimetableImportArgs? args;

  @override
  ConsumerState<TimetableImportPage> createState() =>
      _TimetableImportPageState();
}

class _TimetableImportPageState extends ConsumerState<TimetableImportPage> {
  String? _profileId;
  String? _schoolId;
  bool _createSubjects = true;
  bool _busy = false;

  /// The parent's choice per new subject: an existing subject's id, or null for "create
  /// new". A key not in here follows the scan's suggestion.
  final Map<String, String?> _mergeInto = {};

  String? _targetOf(NewSubject s) =>
      _mergeInto.containsKey(s.key) ? _mergeInto[s.key] : s.suggestedId;

  TimetableImport get _import => widget.args!.import;

  @override
  void initState() {
    super.initState();
    _profileId = widget.args?.profileId;
  }

  /// The children the import may be for: every active child, the named one first.
  List<Member> _children(List<Member> members) {
    final kids = members.where((m) => m.active && m.isChild).toList();
    final named = _import.member == null ? null : foldText(_import.member!);
    if (named != null) {
      kids.sort((a, b) {
        final ma = foldText(a.displayName) == named ? 0 : 1;
        final mb = foldText(b.displayName) == named ? 0 : 1;
        return ma.compareTo(mb);
      });
    }
    return kids;
  }

  SchoolRecord? _school(SchoolData d) {
    final byId = d.schools.where((s) => s.id == _schoolId).firstOrNull;
    if (byId != null) return byId;
    if (_import.school != null) {
      final named = foldText(_import.school!);
      final match = d.schools
          .where((s) => foldText(s.name) == named)
          .firstOrNull;
      if (match != null) return match;
    }
    return d.schools.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final args = widget.args;
    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.schoolImportTitle)),
        body: Center(child: Text(l10n.comingSoon)),
      );
    }
    final data = ref.watch(schoolDataProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolImportTitle)),
      body: ContentWidth(
        child: AbsorbPointer(
          absorbing: _busy,
          child: AsyncValueView(
            value: data,
            onRetry: () => ref.invalidate(schoolDataProvider),
            data: (d) {
              final kids = _children(members);
              final school = _school(d);
              if (kids.isEmpty || school == null) {
                return EmptyView(
                  // A settings page: no Wusel (specs/25 "Where Wusel never appears").
                  illustrated: false,
                  message: kids.isEmpty
                      ? l10n.schoolImportNoChild
                      : l10n.schoolSetupCardBody,
                );
              }
              final child =
                  kids.where((k) => k.id == _profileId).firstOrNull ??
                  kids.first;
              return _Preview(
                args: args,
                data: d,
                kids: kids,
                child: child,
                school: school,
                createSubjects: _createSubjects,
                targetOf: _targetOf,
                busy: _busy,
                onChild: (id) => setState(() => _profileId = id),
                onSchool: (id) => setState(() => _schoolId = id),
                onCreateSubjects: (v) => setState(() => _createSubjects = v),
                onMergeInto: (key, id) => setState(() => _mergeInto[key] = id),
                onApply: (resolved, term) =>
                    _apply(d, child, school, term, resolved),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _apply(
    SchoolData d,
    Member child,
    SchoolRecord school,
    TermRecord? existingTerm,
    ResolvedImport resolved,
  ) async {
    final l10n = context.l10n;
    final repo = ref.read(schoolRepositoryProvider);
    final actor = ref.read(actingProfileProvider);
    setState(() => _busy = true);

    Future<bool> run(Future<Result<Object?>> Function() step) async {
      final result = await step();
      if (!mounted) return false;
      if (result case Err(:final failure)) {
        setState(() => _busy = false);
        context.showFailure(failure);
        return false;
      }
      return true;
    }

    // 1. The term, when the week has none yet.
    var term = existingTerm;
    if (term == null) {
      final year = schoolYearAround(ref.read(selectedWeekProvider));
      final draft = TermRecord(
        id: '',
        schoolId: school.id,
        name: l10n.schoolYearName(
          year.startYear.toString(),
          (year.startYear + 1).toString().substring(2),
        ),
        startsOn: year.from,
        endsOn: year.to,
        isCurrent: true,
      );
      String? termId;
      if (!await run(() async {
        final r = await repo.saveTerm(actor: actor, term: draft);
        termId = r.valueOrNull;
        return r;
      })) {
        return;
      }
      term = TermRecord(
        id: termId!,
        schoolId: draft.schoolId,
        name: draft.name,
        startsOn: draft.startsOn,
        endsOn: draft.endsOn,
        isCurrent: true,
      );
    }

    // 2. More bell times, when the sheet has more periods than the school.
    if (resolved.periods != null) {
      if (!await run(
        () => repo.setPeriods(
          actor: actor,
          schoolId: school.id,
          periods: resolved.periods!,
        ),
      )) {
        return;
      }
    }

    // 3. The subjects the household does not have yet: taken as an existing one, which
    //    then remembers the sheet's word, or created.
    final created = <String, String>{};
    final existing = [...d.subjects];
    for (final s in resolved.newSubjects) {
      final target = _targetOf(s);
      if (target == null) continue;
      created[s.key] = target;
      final subject = existing.where((x) => x.id == target).firstOrNull;
      if (subject == null) continue;
      final known = {
        foldText(subject.shortName),
        foldText(subject.name),
        for (final a in subject.aliases) foldText(a),
      };
      if (known.contains(foldText(s.word)) || subject.aliases.length >= 20) {
        continue;
      }
      final remembered = SubjectRecord(
        id: subject.id,
        name: subject.name,
        shortName: subject.shortName,
        tint: subject.tint,
        iconKey: subject.iconKey,
        equipmentNote: subject.equipmentNote,
        notableDefault: subject.notableDefault,
        aliases: [...subject.aliases, s.word],
      );
      if (!await run(
        () => repo.saveSubject(actor: actor, subject: remembered),
      )) {
        return;
      }
    }
    if (_createSubjects) {
      var i = 0;
      for (final s in resolved.newSubjects) {
        if (created.containsKey(s.key)) continue;
        final record = SubjectRecord(
          id: '',
          name: s.name,
          shortName: s.shortName,
          tint: nextSubjectTint(existing, i++),
        );
        String? id;
        if (!await run(() async {
          final r = await repo.saveSubject(actor: actor, subject: record);
          id = r.valueOrNull;
          return r;
        })) {
          return;
        }
        created[s.key] = id!;
        existing.add(
          SubjectRecord(
            id: id!,
            name: s.name,
            shortName: s.shortName,
            tint: record.tint,
          ),
        );
      }
    }

    // 4. The timetable's metadata, then its whole grid.
    final current = d.timetableOf(child.id, term.id);
    final meta = TimetableRecord(
      id: current?.id ?? '',
      profileId: child.id,
      schoolId: school.id,
      termId: term.id,
      classLabel: _import.classLabel ?? current?.classLabel,
      weekCycle: resolved.weekCycle,
      validFrom: term.startsOn,
    );
    String? timetableId = current?.id;
    if (!await run(() async {
      final r = await repo.saveTimetable(actor: actor, timetable: meta);
      timetableId = r.valueOrNull;
      return r;
    })) {
      return;
    }
    final lessons = <LessonRecord>[
      for (final l in resolved.lessons)
        if (l.subjectId != null || created.containsKey(l.newSubjectKey))
          LessonRecord(
            id: '',
            timetableId: timetableId!,
            weekday: l.weekday,
            periodIndex: l.period,
            subjectId: l.subjectId ?? created[l.newSubjectKey],
            teacher: l.teacher,
            room: l.room,
            weekParity: l.parity,
          ),
      for (final c in resolved.care)
        for (final day in c.days.toList()..sort())
          LessonRecord(
            id: '',
            timetableId: timetableId!,
            weekday: day,
            kind: 'care',
            title: c.title,
            startsAt: c.starts,
            endsAt: c.ends,
          ),
    ];
    if (!await run(
      () => repo.setLessons(
        actor: actor,
        timetableId: timetableId!,
        lessons: lessons,
      ),
    )) {
      return;
    }

    ref
      ..invalidate(schoolDataProvider)
      ..invalidate(schoolWeekProvider);
    ref.read(selectedChildIdProvider.notifier).select(child.id);
    if (!mounted) return;
    context.showMessage(l10n.schoolImportApplied);
    Navigator.of(context).pop(true);
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({
    required this.args,
    required this.data,
    required this.kids,
    required this.child,
    required this.school,
    required this.createSubjects,
    required this.targetOf,
    required this.busy,
    required this.onChild,
    required this.onSchool,
    required this.onCreateSubjects,
    required this.onMergeInto,
    required this.onApply,
  });

  final TimetableImportArgs args;
  final SchoolData data;
  final List<Member> kids;
  final Member child;
  final SchoolRecord school;
  final bool createSubjects;

  /// The existing subject a new one is taken as, or null for a new subject.
  final String? Function(NewSubject) targetOf;
  final bool busy;
  final ValueChanged<String> onChild;
  final ValueChanged<String> onSchool;
  final ValueChanged<bool> onCreateSubjects;
  final void Function(String key, String? subjectId) onMergeInto;
  final void Function(ResolvedImport resolved, TermRecord? term) onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final import = args.import;
    final periods = data.periods.where((p) => p.schoolId == school.id).toList();
    final resolved = resolveImport(
      import,
      subjects: data.subjects,
      periods: periods,
      schoolId: school.id,
      schoolName: school.name,
    );
    final around = ref.watch(selectedWeekProvider);
    final term = data.termFor(around, schoolId: school.id);
    final year = schoolYearAround(around);
    final termName =
        term?.name ??
        l10n.schoolYearName(
          year.startYear.toString(),
          (year.startYear + 1).toString().substring(2),
        );
    final existing = term == null ? null : data.timetableOf(child.id, term.id);
    final existingCount = existing == null
        ? 0
        : data.lessons.where((l) => l.timetableId == existing.id).length;
    final compactControls =
        MediaQuery.sizeOf(context).width < 560 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final kept = resolved.lessons
        .where((l) => l.subjectId != null || createSubjects)
        .length;
    final gridPeriods =
        (resolved.periods ?? periods).where((p) => !p.isBreak).toList()
          ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            children: [
              Text(l10n.schoolChooseChild, style: theme.textTheme.labelLarge),
              const SizedBox(height: Tokens.space2),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in kids)
                    ChoiceChip(
                      key: ValueKey('import-child-${k.id}'),
                      label: Text(k.displayName),
                      selected: k.id == child.id,
                      onSelected: (_) => onChild(k.id),
                    ),
                ],
              ),
              if (data.schools.length > 1) ...[
                const SizedBox(height: Tokens.space3),
                DropdownButtonFormField<String>(
                  initialValue: school.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.schoolsUiPickSchool,
                  ),
                  items: [
                    for (final s in data.schools)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) onSchool(v);
                  },
                ),
              ],
              const SizedBox(height: Tokens.space4),
              Text(
                [
                  l10n.schoolImportLessons(kept),
                  if (import.classLabel != null)
                    '${l10n.schoolEditorClass} ${import.classLabel}',
                  resolved.weekCycle == 'ab'
                      ? l10n.schoolCycleAb
                      : l10n.schoolCycleWeekly,
                ].join(' · '),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                term == null
                    ? l10n.schoolImportTermNew(termName)
                    : l10n.schoolImportTermExisting(termName),
                style: theme.textTheme.bodyMedium,
              ),
              if (existing != null) ...[
                const SizedBox(height: Tokens.space2),
                _Note(
                  icon: Icons.sync_alt,
                  text: l10n.schoolImportReplaces(
                    child.displayName,
                    existingCount,
                  ),
                ),
              ],
              for (final w in resolved.warnings) ...[
                const SizedBox(height: Tokens.space2),
                _Note(icon: Icons.info_outline, text: _warning(l10n, w)),
              ],
              if (args.unplaced > 0) ...[
                const SizedBox(height: Tokens.space2),
                _Note(
                  icon: Icons.info_outline,
                  text: l10n.schoolScanWarnUnplaced(args.unplaced),
                ),
              ],
              const SizedBox(height: Tokens.space4),
              _Grid(
                periods: gridPeriods,
                lessons: resolved.lessons,
                subjects: data.subjects,
                newSubjects: resolved.newSubjects,
                targets: {
                  for (final s in resolved.newSubjects) s.key: targetOf(s),
                },
                createSubjects: createSubjects,
                iconKeyOf: data.iconKeyFor,
              ),
              if (resolved.care.isNotEmpty) ...[
                const SizedBox(height: Tokens.space4),
                Text(l10n.schoolCareRows, style: theme.textTheme.titleMedium),
                for (final c in resolved.care)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.title),
                    subtitle: Text(
                      '${(c.days.toList()..sort()).map((d) => context.weekdayShort(_weekdayDate(d))).join(', ')} · '
                      '${context.span(c.starts, c.ends)}',
                    ),
                  ),
              ],
              if (resolved.newSubjects.isNotEmpty) ...[
                const SizedBox(height: Tokens.space4),
                Text(
                  l10n.schoolImportNewSubjects,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: Tokens.space1),
                Text(
                  l10n.schoolImportMergeHint,
                  style: theme.textTheme.bodySmall,
                ),
                for (final s in resolved.newSubjects)
                  compactControls
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${s.name} (${s.shortName})'),
                            DropdownButton<String>(
                              key: ValueKey('import-merge-${s.key}'),
                              isExpanded: true,
                              value: targetOf(s) ?? '',
                              underline: const SizedBox.shrink(),
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(l10n.schoolImportCreateNew),
                                ),
                                for (final x in data.subjects)
                                  DropdownMenuItem(
                                    value: x.id,
                                    child: Text(x.name),
                                  ),
                              ],
                              onChanged: (v) => onMergeInto(
                                s.key,
                                v == null || v.isEmpty ? null : v,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: Text('${s.name} (${s.shortName})')),
                            DropdownButton<String>(
                              key: ValueKey('import-merge-${s.key}'),
                              value: targetOf(s) ?? '',
                              underline: const SizedBox.shrink(),
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(l10n.schoolImportCreateNew),
                                ),
                                for (final x in data.subjects)
                                  DropdownMenuItem(
                                    value: x.id,
                                    child: Text(x.name),
                                  ),
                              ],
                              onChanged: (v) => onMergeInto(
                                s.key,
                                v == null || v.isEmpty ? null : v,
                              ),
                            ),
                          ],
                        ),
                if (resolved.newSubjects.any((s) => targetOf(s) == null))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.schoolImportCreateSubjects),
                    subtitle: createSubjects
                        ? null
                        : Text(l10n.schoolImportSkipNewSubjects),
                    value: createSubjects,
                    onChanged: onCreateSubjects,
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('import-apply'),
                    onPressed: busy || kept == 0
                        ? null
                        : () => onApply(resolved, term),
                    child: Text(l10n.schoolImportApply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _warning(AppLocalizations l10n, ImportWarning w) => switch (w.kind) {
    ImportWarningKind.unmatchedTimes => l10n.schoolImportWarnUnmatchedTimes(
      w.count,
    ),
    ImportWarningKind.periodsExtended => l10n.schoolImportWarnPeriodsExtended(
      w.count,
    ),
    ImportWarningKind.periodsDiffer => l10n.schoolImportWarnPeriodsDiffer,
    ImportWarningKind.schoolDiffers => l10n.schoolImportWarnSchoolDiffers(
      w.detail ?? '',
    ),
  };
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: Tokens.space2),
      Expanded(child: Text(text)),
    ],
  );
}

/// Monday 2 January 2023 is a Monday: a date for each weekday name (1 = Monday).
DateTime _weekdayDate(int weekday) =>
    DateTime(2023, 1, 2).add(Duration(days: weekday - 1));

/// The grid as it will be saved: a row per period, a column per weekday in use.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.periods,
    required this.lessons,
    required this.subjects,
    required this.newSubjects,
    required this.targets,
    required this.createSubjects,
    required this.iconKeyOf,
  });

  final List<PeriodRecord> periods;
  final List<ResolvedLesson> lessons;
  final List<SubjectRecord> subjects;
  final List<NewSubject> newSubjects;

  /// Per new subject key, the existing subject it is taken as (null: created).
  final Map<String, String?> targets;
  final bool createSubjects;
  final String? Function(String name) iconKeyOf;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final theme = Theme.of(context);
    final days = [
      for (var d = 1; d <= 7; d++)
        if (d <= 5 || lessons.any((l) => l.weekday == d)) d,
    ];
    final byId = {for (final s in subjects) s.id: s};
    final byKey = {for (final s in newSubjects) s.key: s};
    String? idOf(ResolvedLesson l) => l.subjectId ?? targets[l.newSubjectKey];
    String label(ResolvedLesson l) {
      final id = idOf(l);
      if (id != null) return byId[id]?.shortName ?? '?';
      return byKey[l.newSubjectKey]?.shortName ?? '?';
    }

    bool dropped(ResolvedLesson l) => idOf(l) == null && !createSubjects;

    // The subject's name under its short name; null when the name is only the word
    // again (a new "Hort" shows once).
    String? nameOf(ResolvedLesson l) {
      final id = idOf(l);
      final name = id != null ? byId[id]?.name : byKey[l.newSubjectKey]?.name;
      if (name == null || foldText(name) == foldText(label(l))) return null;
      return name;
    }

    Widget cell(ResolvedLesson l, bool compact) {
      final name = nameOf(l);
      final row = Row(
        children: [
          if (l.parity != 'all')
            Text(
              l.parity.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          if (idOf(l) != null) ...[
            Icon(schoolIcon(byId[idOf(l)]?.iconKey), size: 14),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: Text(
              label(l),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dropped(l) ? ww.ink2 : null,
                decoration: dropped(l) ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          // On a phone the room would push the short name out of its cell: it goes into
          // the long press with the name.
          if (l.room != null && !compact)
            Flexible(
              child: Text(
                l.room!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: ww.ink2),
              ),
            ),
        ],
      );
      if (compact) {
        // A vertical cell remains readable when large text makes the grid narrow.
        final compactCell = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (l.parity != 'all')
              Text(
                l.parity.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            Text(
              label(l),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dropped(l) ? ww.ink2 : null,
                decoration: dropped(l) ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        );
        if (name == null && l.room == null) return compactCell;
        // No room for the name on a phone: a long press tells it, and the room.
        return Tooltip(
          message: [label(l), ?name, ?l.room].join(' · '),
          triggerMode: TooltipTriggerMode.longPress,
          child: compactCell,
        );
      }
      if (name == null) return row;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          Text(
            name,
            key: ValueKey('import-cell-name-${l.weekday}-${l.period}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: ww.ink2,
              decoration: dropped(l) ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        // Keep useful space for each day at large text sizes. Narrow screens can
        // scroll the preview horizontally instead of squeezing the lesson rows.
        final periodWidth = 80 * textScale;
        final dayWidth = 60 * textScale;
        final tableWidth = periodWidth + days.length * dayWidth;
        final compact = constraints.maxWidth < 560 || textScale > 1.2;
        return _PreviewScroller(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: tableWidth > constraints.maxWidth
                  ? tableWidth
                  : constraints.maxWidth,
            ),
            child: Table(
              border: TableBorder.all(color: ww.line),
              columnWidths: {
                0: FixedColumnWidth(periodWidth),
                for (var i = 1; i <= days.length; i++)
                  i: FixedColumnWidth(dayWidth),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    for (final d in days)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          context.weekdayShort(_weekdayDate(d)),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  ],
                ),
                for (final p in periods)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.index}.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              context.span(p.starts, p.ends),
                              style: TextStyle(fontSize: 11, color: ww.ink2),
                            ),
                          ],
                        ),
                      ),
                      for (final d in days)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l in lessons)
                                if (l.weekday == d && l.period == p.index)
                                  cell(l, compact),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A keyboard stop inside the horizontal scroll region, with a visible focus cue.
class _PreviewScroller extends StatefulWidget {
  const _PreviewScroller({required this.child});
  final Widget child;

  @override
  State<_PreviewScroller> createState() => _PreviewScrollerState();
}

class _PreviewScrollerState extends State<_PreviewScroller> {
  final _scroll = ScrollController();
  bool _focused = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: _scroll,
    scrollDirection: Axis.horizontal,
    child: Focus(
      key: const ValueKey('import-preview-scroll-focus'),
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (_, event) {
        if (event is KeyUpEvent || !_scroll.hasClients) {
          return KeyEventResult.ignored;
        }
        final direction = event.logicalKey == LogicalKeyboardKey.arrowRight
            ? 1
            : event.logicalKey == LogicalKeyboardKey.arrowLeft
            ? -1
            : 0;
        if (direction == 0) return KeyEventResult.ignored;
        _scroll.jumpTo(
          (_scroll.offset + direction * 80).clamp(
            _scroll.position.minScrollExtent,
            _scroll.position.maxScrollExtent,
          ),
        );
        return KeyEventResult.handled;
      },
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            width: 2,
            color: _focused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: widget.child,
      ),
    ),
  );
}
