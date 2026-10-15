import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/region/ui/holiday_import_sheet.dart';
import 'package:wuselwall/features/region/ui/region_field.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// The schools of the household, their bell times, terms and holidays, and the subjects
/// they share (specs/15 "Maintaining it"). One school is on screen at a time; a
/// household with siblings at different schools adds the others here. Guardian only;
/// the server refuses the writes of anyone else. The starter content (bell times,
/// subjects) is example data the family renames.
class SchoolSetupPage extends ConsumerStatefulWidget {
  const SchoolSetupPage({this.initialSchoolId, super.key});

  /// The school to open on (the `school` query parameter); null means the first.
  final String? initialSchoolId;

  @override
  ConsumerState<SchoolSetupPage> createState() => _SchoolSetupPageState();
}

class _SchoolSetupPageState extends ConsumerState<SchoolSetupPage> {
  String? _selectedId;

  /// True while the empty form for another school is on screen.
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSchoolId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = ref.watch(schoolDataProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolSetupTitle)),
      body: AsyncValueView(
        value: data,
        onRetry: () => ref.invalidate(schoolDataProvider),
        data: (d) {
          final school = _adding
              ? null
              : d.schools.where((s) => s.id == _selectedId).firstOrNull ??
                    d.schools.firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (d.schools.length > 1)
                _SchoolSwitcher(
                  schools: d.schools,
                  selected: school,
                  onSelected: (id) => setState(() {
                    _adding = false;
                    _selectedId = id;
                  }),
                ),
              if (!_adding)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _adding = true),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.schoolsUiAddSchool),
                  ),
                ),
              _SchoolForm(
                key: ValueKey('school-form-${school?.id ?? 'new'}'),
                school: school,
                onCreated: (id) => setState(() {
                  _adding = false;
                  _selectedId = id;
                }),
              ),
              if (school != null) ...[
                _BellTimes(
                  key: ValueKey('bells-${school.id}'),
                  data: d,
                  school: school,
                ),
                _Terms(data: d, school: school),
                _Holidays(data: d, school: school),
              ],
              _Subjects(data: d),
            ],
          );
        },
      ),
    );
  }
}

/// Two to four schools as segments, more as a dropdown.
class _SchoolSwitcher extends StatelessWidget {
  const _SchoolSwitcher({
    required this.schools,
    required this.selected,
    required this.onSelected,
  });

  final List<SchoolRecord> schools;
  final SchoolRecord? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final switcher = schools.length <= 4
        ? SegmentedButton<String>(
            segments: [
              for (final s in schools)
                ButtonSegment(value: s.id, label: Text(s.name)),
            ],
            selected: {?selected?.id},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (s) => onSelected(s.first),
          )
        : DropdownButtonFormField<String>(
            key: ValueKey('school-dropdown-${selected?.id}'),
            initialValue: selected?.id,
            decoration: InputDecoration(labelText: l10n.schoolsUiPickSchool),
            items: [
              for (final s in schools)
                DropdownMenuItem<String>(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) {
              if (v != null) onSelected(v);
            },
          );
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: switcher);
  }
}

/// Saves the change through [action]; a failure is shown, a success refetches the data.
/// Returns whether the write went through.
Future<bool> _write(
  BuildContext context,
  WidgetRef ref,
  Future<Result<Object?>> Function(String? actor) action,
) async {
  final result = await action(ref.read(actingProfileProvider));
  if (!context.mounted) return false;
  switch (result) {
    case Err(:final failure):
      context.showFailure(failure);
      return false;
    case Ok():
      ref.invalidate(schoolDataProvider);
      ref.invalidate(schoolWeekProvider);
      context.showMessage(context.l10n.schoolSaved);
      return true;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

/// The school's name and region. Keyed by the school's id by the page, so switching
/// schools starts from that school's values. [school] null is the empty form for a new
/// school, which proposes the household's region; [onCreated] receives the new id once it
/// is saved.
class _SchoolForm extends ConsumerStatefulWidget {
  const _SchoolForm({required this.school, required this.onCreated, super.key});

  final SchoolRecord? school;
  final ValueChanged<String> onCreated;

  @override
  ConsumerState<_SchoolForm> createState() => _SchoolFormState();
}

class _SchoolFormState extends ConsumerState<_SchoolForm> {
  late final _name = TextEditingController(text: widget.school?.name ?? '');

  /// What the user picked or cleared; used once [_touched] is set.
  String? _picked;
  bool _touched = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The region on screen: the school's own, or for a new school the household's.
  String? _regionOn(List<SettingEntry> settings) {
    if (_touched) return _picked;
    final school = widget.school;
    if (school != null) return school.regionCode;
    return resolveSetting(settings, 'household.region')?.value as String?;
  }

  /// The first school with a region also sets the household's region, when it has none
  /// yet (specs/04: the region is asked with the first school). A region already set stays.
  Future<void> _proposeHouseholdRegion(String region) async {
    final repository = ref.read(householdSettingsRepositoryProvider);
    final entries = (await repository.all()).valueOrNull ?? const [];
    if (resolveSetting(entries, 'household.region')?.value != null) return;
    final result = await repository.set(
      actor: ref.read(actingProfileProvider),
      key: 'household.region',
      value: region,
    );
    if (!mounted) return;
    if (result.isOk) ref.invalidate(householdSettingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings =
        ref.watch(householdSettingsProvider).value ?? const <SettingEntry>[];
    return _Section(
      title: widget.school == null
          ? l10n.schoolsUiNewSchool
          : l10n.schoolSectionSchool,
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.schoolName),
        ),
        const SizedBox(height: 12),
        RegionField(
          code: _regionOn(settings),
          onChanged: (code) => setState(() {
            _touched = true;
            _picked = code;
          }),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              final region = _regionOn(settings);
              String? savedId;
              final saved = await _write(context, ref, (actor) async {
                final result = await ref
                    .read(schoolRepositoryProvider)
                    .saveSchool(
                      actor: actor,
                      id: widget.school?.id,
                      name: name,
                      regionCode: region,
                      // A new school takes the household's timezone on the server;
                      // an existing one keeps its own.
                      timezone: widget.school?.timezone,
                    );
                savedId = result.valueOrNull;
                return result;
              });
              if (saved && region != null) {
                await _proposeHouseholdRegion(region);
              }
              final id = savedId;
              if (saved && widget.school == null && id != null) {
                widget.onCreated(id);
              }
            },
            child: Text(l10n.save),
          ),
        ),
      ],
    );
  }
}

/// Bell times in order: a lesson (its index counts up) and the break after it.
class _BellTimes extends ConsumerStatefulWidget {
  const _BellTimes({required this.data, required this.school, super.key});

  final SchoolData data;
  final SchoolRecord school;

  @override
  ConsumerState<_BellTimes> createState() => _BellTimesState();
}

class _BellRow {
  _BellRow({required this.isBreak, required this.starts, required this.ends});

  final bool isBreak;
  TimeOfDay starts;
  TimeOfDay ends;
}

class _BellTimesState extends ConsumerState<_BellTimes> {
  late final List<_BellRow> _rows = [
    for (final p in widget.data.periods.where(
      (p) => p.schoolId == widget.school.id,
    ))
      _BellRow(isBreak: p.isBreak, starts: p.starts, ends: p.ends),
  ];

  /// Indexes follow the order: lessons count up, a break takes the lesson before it.
  List<PeriodRecord> _periods() {
    var lesson = 0;
    return [
      for (final r in _rows)
        if (r.isBreak)
          PeriodRecord(
            schoolId: widget.school.id,
            index: lesson,
            starts: r.starts,
            ends: r.ends,
            kind: 'break',
          )
        else
          PeriodRecord(
            schoolId: widget.school.id,
            index: ++lesson,
            starts: r.starts,
            ends: r.ends,
            kind: 'lesson',
          ),
    ];
  }

  Future<void> _pick(_BellRow row, {required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? row.starts : row.ends,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        row.starts = picked;
      } else {
        row.ends = picked;
      }
    });
  }

  void _add({required bool isBreak}) {
    final last = _rows.isEmpty ? null : _rows.last.ends;
    final start = last ?? const TimeOfDay(hour: 8, minute: 0);
    final minutes = start.hour * 60 + start.minute;
    TimeOfDay at(int m) => TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
    setState(() {
      _rows.add(
        _BellRow(
          isBreak: isBreak,
          starts: start,
          ends: at(minutes + (isBreak ? 20 : 45)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    var lessonNo = 0;
    return _Section(
      title: l10n.schoolBellTimes,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Builder(
            builder: (context) {
              final r = _rows[i];
              if (!r.isBreak) lessonNo++;
              return Card(
                child: ListTile(
                  title: Text(
                    r.isBreak ? l10n.boardBreak : l10n.boardPeriod(lessonNo),
                  ),
                  subtitle: Row(
                    children: [
                      Tooltip(
                        message: l10n.schoolStart,
                        child: TextButton(
                          onPressed: () => _pick(r, start: true),
                          child: Text(context.time(r.starts)),
                        ),
                      ),
                      const Text('–'),
                      Tooltip(
                        message: l10n.schoolEnd,
                        child: TextButton(
                          onPressed: () => _pick(r, start: false),
                          child: Text(context.time(r.ends)),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: l10n.schoolRemove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _rows.removeAt(i)),
                  ),
                ),
              );
            },
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _add(isBreak: false),
              child: Text(l10n.schoolAddLesson),
            ),
            OutlinedButton(
              onPressed: () => _add(isBreak: true),
              child: Text(l10n.schoolAddBreak),
            ),
            FilledButton(
              onPressed: () => unawaited(
                _write(
                  context,
                  ref,
                  (actor) => ref
                      .read(schoolRepositoryProvider)
                      .setPeriods(
                        actor: actor,
                        schoolId: widget.school.id,
                        periods: _periods(),
                      ),
                ),
              ),
              child: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }
}

class _Terms extends ConsumerWidget {
  const _Terms({required this.data, required this.school});

  final SchoolData data;
  final SchoolRecord school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final terms = data.terms.where((t) => t.schoolId == school.id).toList();
    return _Section(
      title: l10n.schoolTerms,
      action: IconButton(
        tooltip: l10n.schoolAddTerm,
        icon: const Icon(Icons.add),
        onPressed: () async {
          final term = await showDialog<TermRecord>(
            context: context,
            builder: (_) => _TermDialog(schoolId: school.id),
          );
          if (term == null || !context.mounted) return;
          await _write(
            context,
            ref,
            (actor) => ref
                .read(schoolRepositoryProvider)
                .saveTerm(actor: actor, term: term),
          );
        },
      ),
      children: [
        for (final t in terms)
          Card(
            child: ListTile(
              title: Text(t.name),
              subtitle: Text(
                '${context.dayMonth(t.startsOn)} ${t.startsOn.year} – '
                '${context.dayMonth(t.endsOn)} ${t.endsOn.year}'
                '${t.isCurrent ? ' · ${l10n.schoolCurrent}' : ''}',
              ),
              onTap: () async {
                final edited = await showDialog<TermRecord>(
                  context: context,
                  builder: (_) => _TermDialog(schoolId: school.id, term: t),
                );
                if (edited == null || !context.mounted) return;
                await _write(
                  context,
                  ref,
                  (actor) => ref
                      .read(schoolRepositoryProvider)
                      .saveTerm(actor: actor, term: edited),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TermDialog extends StatefulWidget {
  const _TermDialog({required this.schoolId, this.term});

  final String schoolId;
  final TermRecord? term;

  @override
  State<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<_TermDialog> {
  late final _name = TextEditingController(text: widget.term?.name ?? '');
  late final _anchor = TextEditingController(
    text: widget.term?.abAnchorWeek?.toString() ?? '',
  );
  late DateTime _from = widget.term?.startsOn ?? DateTime.now();
  late DateTime _to = widget.term?.endsOn ?? DateTime.now();
  late bool _current = widget.term?.isCurrent ?? false;

  @override
  void dispose() {
    _name.dispose();
    _anchor.dispose();
    super.dispose();
  }

  Future<void> _date({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.schoolTermEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.schoolTermName),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _date(from: true),
                    child: Text(
                      '${l10n.schoolFrom} ${context.dayMonth(_from)} ${_from.year}',
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _date(from: false),
                    child: Text(
                      '${l10n.schoolTo} ${context.dayMonth(_to)} ${_to.year}',
                    ),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _anchor,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.schoolAbWeek,
                helperText: l10n.schoolAbWeekHint,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.schoolCurrent),
              value: _current,
              onChanged: (v) => setState(() => _current = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final anchor = int.tryParse(_anchor.text.trim());
            Navigator.of(context).pop(
              TermRecord(
                id: widget.term?.id ?? '',
                schoolId: widget.schoolId,
                name: name,
                startsOn: _from,
                endsOn: _to,
                abAnchorWeek: anchor,
                isCurrent: _current,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _Subjects extends ConsumerWidget {
  const _Subjects({required this.data});

  final SchoolData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Section(
      title: l10n.schoolSubjects,
      action: IconButton(
        tooltip: l10n.schoolAddSubject,
        icon: const Icon(Icons.add),
        onPressed: () async {
          final s = await showDialog<SubjectRecord>(
            context: context,
            builder: (_) => const _SubjectDialog(),
          );
          if (s == null || !context.mounted) return;
          await _write(
            context,
            ref,
            (actor) => ref
                .read(schoolRepositoryProvider)
                .saveSubject(actor: actor, subject: s),
          );
        },
      ),
      children: [
        for (final s in data.subjects)
          Card(
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PaperTints.tints
                      .where((t) => t.key == s.tint)
                      .firstOrNull
                      ?.of(
                        Theme.of(context).brightness == Brightness.dark
                            ? Shade.dark
                            : Shade.light,
                      ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(schoolIcon(s.iconKey), size: 20),
              ),
              title: Text('${s.name} (${s.shortName})'),
              subtitle: Text(
                [
                  if (s.equipmentNote != null) s.equipmentNote!,
                  if (s.notableDefault) l10n.schoolNotable,
                ].join(' · '),
              ),
              onTap: () async {
                final edited = await showDialog<SubjectRecord>(
                  context: context,
                  builder: (_) => _SubjectDialog(subject: s),
                );
                if (edited == null || !context.mounted) return;
                await _write(
                  context,
                  ref,
                  (actor) => ref
                      .read(schoolRepositoryProvider)
                      .saveSubject(actor: actor, subject: edited),
                );
              },
              trailing: IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(
                  _write(
                    context,
                    ref,
                    (actor) => ref
                        .read(schoolRepositoryProvider)
                        .deleteSubject(actor: actor, id: s.id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({this.subject});

  final SubjectRecord? subject;

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  late final _name = TextEditingController(text: widget.subject?.name ?? '');
  late final _short = TextEditingController(
    text: widget.subject?.shortName ?? '',
  );
  late final _equipment = TextEditingController(
    text: widget.subject?.equipmentNote ?? '',
  );
  late String _tint = widget.subject?.tint ?? 'blue';
  late bool _notable = widget.subject?.notableDefault ?? false;

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _equipment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shade = Theme.of(context).brightness == Brightness.dark
        ? Shade.dark
        : Shade.light;
    return AlertDialog(
      title: Text(l10n.schoolSubjectEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.schoolTermName),
            ),
            TextField(
              controller: _short,
              decoration: InputDecoration(labelText: l10n.schoolSubjectShort),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.schoolTint),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final t in PaperTints.tints)
                  ChoiceChip(
                    label: const SizedBox(width: 14, height: 14),
                    selected: _tint == t.key,
                    selectedColor: t.of(shade),
                    backgroundColor: t.of(shade),
                    onSelected: (_) => setState(() => _tint = t.key),
                  ),
              ],
            ),
            TextField(
              controller: _equipment,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.schoolEquipment),
            ),
            const SizedBox(height: Tokens.space2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.schoolNotable),
              value: _notable,
              onChanged: (v) => setState(() => _notable = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final short = _short.text.trim();
            if (name.isEmpty || short.isEmpty) return;
            Navigator.of(context).pop(
              SubjectRecord(
                id: widget.subject?.id ?? '',
                name: name,
                shortName: short,
                tint: _tint,
                iconKey: widget.subject?.iconKey,
                equipmentNote: _equipment.text.trim().isEmpty
                    ? null
                    : _equipment.text.trim(),
                notableDefault: _notable,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _Holidays extends ConsumerWidget {
  const _Holidays({required this.data, required this.school});

  final SchoolData data;
  final SchoolRecord school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final holidays = data.holidays
        .where((h) => h.schoolId == null || h.schoolId == school.id)
        .toList();
    final region = school.regionCode;
    return _Section(
      title: l10n.schoolHolidays,
      action: IconButton(
        tooltip: l10n.schoolAddHoliday,
        icon: const Icon(Icons.add),
        onPressed: () async {
          final h = await showDialog<HolidayRecord>(
            context: context,
            builder: (_) => _HolidayDialog(schoolId: school.id),
          );
          if (h == null || !context.mounted) return;
          await _write(
            context,
            ref,
            (actor) => ref
                .read(schoolRepositoryProvider)
                .saveHoliday(actor: actor, holiday: h),
          );
        },
      ),
      children: [
        OutlinedButton.icon(
          onPressed: region == null
              ? null
              : () => _importHolidays(context, ref, school),
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.regionImportAction),
        ),
        if (region == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.regionImportNeedsRegion),
          ),
        const SizedBox(height: 8),
        for (final h in holidays)
          Card(
            child: ListTile(
              title: Text(h.name),
              subtitle: Text(
                [
                  '${context.dayMonth(h.startsOn)} – ${context.dayMonth(h.endsOn)}',
                  if (h.isImported) l10n.regionImported,
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(
                  _write(
                    context,
                    ref,
                    (actor) => ref
                        .read(schoolRepositoryProvider)
                        .deleteHoliday(actor: actor, id: h.id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens the import sheet for [school]'s region; a successful import refetches the data.
Future<void> _importHolidays(
  BuildContext context,
  WidgetRef ref,
  SchoolRecord school,
) async {
  final region = school.regionCode;
  if (region == null) return;
  final count = await showHolidayImportSheet(context, (
    schoolId: school.id,
    region: region,
  ));
  if (count == null || !context.mounted) return;
  context.showMessage(context.l10n.regionImportDone(count));
  ref.invalidate(schoolDataProvider);
  ref.invalidate(schoolWeekProvider);
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog({required this.schoolId});

  final String schoolId;

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final _name = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _date({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.schoolHolidayEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.schoolHolidayName),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _date(from: true),
                  child: Text('${l10n.schoolFrom} ${context.dayMonth(_from)}'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _date(from: false),
                  child: Text('${l10n.schoolTo} ${context.dayMonth(_to)}'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              HolidayRecord(
                id: '',
                schoolId: widget.schoolId,
                name: name,
                startsOn: _from,
                endsOn: _to.isBefore(_from) ? _from : _to,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
