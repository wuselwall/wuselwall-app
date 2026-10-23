import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/proposals_repository.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';

/// What the import preview opens on: a parsed payload, and the proposal it came from
/// when an assistant handed it in (specs/24).
class TimetableImportArgs {
  const TimetableImportArgs({
    required this.import,
    this.proposalId,
    this.assistantLabel,
    this.profileId,
    this.unplaced = 0,
  });

  final TimetableImport import;
  final String? proposalId;
  final String? assistantLabel;

  /// The child to preselect; else the one the payload names, else the first.
  final String? profileId;

  /// From a scan: text pieces that fit no cell, so the parent knows to check.
  final int unplaced;
}

/// The preview before anything is written (specs/24 "The preview"): the child, the
/// school, the term it will land in, the grid as it will look, the subjects that will be
/// created, and every warning. Nothing exists until Übernehmen; a proposal is marked
/// applied or rejected with the same tap. Guardian only (the server decides).
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
      body: AbsorbPointer(
        absorbing: _busy,
        child: AsyncValueView(
          value: data,
          onRetry: () => ref.invalidate(schoolDataProvider),
          data: (d) {
            final kids = _children(members);
            final school = _school(d);
            if (kids.isEmpty || school == null) {
              return EmptyView(
                message: kids.isEmpty
                    ? l10n.schoolImportNoChild
                    : l10n.schoolSetupCardBody,
              );
            }
            final child =
                kids.where((k) => k.id == _profileId).firstOrNull ?? kids.first;
            return _Preview(
              args: args,
              data: d,
              kids: kids,
              child: child,
              school: school,
              createSubjects: _createSubjects,
              busy: _busy,
              onChild: (id) => setState(() => _profileId = id),
              onSchool: (id) => setState(() => _schoolId = id),
              onCreateSubjects: (v) => setState(() => _createSubjects = v),
              onApply: (resolved, term) =>
                  _apply(d, child, school, term, resolved),
              onDiscard: args.proposalId == null ? null : _discard,
            );
          },
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

    // 3. The subjects the household does not have yet.
    final created = <String, String>{};
    if (_createSubjects) {
      final existing = [...d.subjects];
      var i = 0;
      for (final s in resolved.newSubjects) {
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

    // 5. The verdict on the proposal, when there was one.
    final proposalId = widget.args?.proposalId;
    if (proposalId != null) {
      if (!await run(
        () => ref
            .read(proposalsRepositoryProvider)
            .resolve(actor: actor, id: proposalId, applied: true),
      )) {
        return;
      }
    }

    ref
      ..invalidate(schoolDataProvider)
      ..invalidate(schoolWeekProvider)
      ..invalidate(openProposalsProvider);
    ref.read(selectedChildIdProvider.notifier).select(child.id);
    if (!mounted) return;
    context.showMessage(l10n.schoolImportApplied);
    Navigator.of(context).pop(true);
  }

  Future<void> _discard() async {
    final proposalId = widget.args!.proposalId!;
    setState(() => _busy = true);
    final result = await ref
        .read(proposalsRepositoryProvider)
        .resolve(
          actor: ref.read(actingProfileProvider),
          id: proposalId,
          applied: false,
        );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
      case Ok():
        ref.invalidate(openProposalsProvider);
        context.showMessage(context.l10n.schoolImportDiscarded);
        Navigator.of(context).pop(false);
    }
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
    required this.busy,
    required this.onChild,
    required this.onSchool,
    required this.onCreateSubjects,
    required this.onApply,
    required this.onDiscard,
  });

  final TimetableImportArgs args;
  final SchoolData data;
  final List<Member> kids;
  final Member child;
  final SchoolRecord school;
  final bool createSubjects;
  final bool busy;
  final ValueChanged<String> onChild;
  final ValueChanged<String> onSchool;
  final ValueChanged<bool> onCreateSubjects;
  final void Function(ResolvedImport resolved, TermRecord? term) onApply;
  final VoidCallback? onDiscard;

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
              if (args.assistantLabel case final assistant?) ...[
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: Tokens.space2),
                    Expanded(
                      child: Text(
                        l10n.schoolImportProposedBy(assistant),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Tokens.space3),
              ],
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
                  resolved.newSubjects
                      .map((s) => '${s.name} (${s.shortName})')
                      .join(', '),
                ),
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
                if (onDiscard != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('import-discard'),
                      onPressed: busy ? null : onDiscard,
                      child: Text(l10n.schoolImportDiscard),
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                ],
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
    required this.createSubjects,
    required this.iconKeyOf,
  });

  final List<PeriodRecord> periods;
  final List<ResolvedLesson> lessons;
  final List<SubjectRecord> subjects;
  final List<NewSubject> newSubjects;
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
    String label(ResolvedLesson l) {
      if (l.subjectId != null) return byId[l.subjectId]?.shortName ?? '?';
      return byKey[l.newSubjectKey]?.shortName ?? '?';
    }

    return Table(
      border: TableBorder.all(color: ww.line),
      columnWidths: const {0: FixedColumnWidth(72)},
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
                child: Text(
                  '${p.index}. ${context.time(p.starts)}',
                  style: theme.textTheme.labelSmall,
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
                          Row(
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
                              if (l.subjectId != null) ...[
                                Icon(
                                  schoolIcon(byId[l.subjectId]?.iconKey),
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                              ],
                              Expanded(
                                child: Text(
                                  label(l),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        l.subjectId == null && !createSubjects
                                        ? ww.ink2
                                        : null,
                                    decoration:
                                        l.subjectId == null && !createSubjects
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (l.room != null)
                                Text(
                                  l.room!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ww.ink2,
                                  ),
                                ),
                            ],
                          ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
