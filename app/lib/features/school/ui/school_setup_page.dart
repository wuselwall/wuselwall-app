import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/region/ui/holiday_import_sheet.dart';
import 'package:wuselwall/features/region/ui/region_field.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/open_timetable_editor.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';
import 'package:wuselwall/features/school/ui/timetable_import_menu.dart';
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
  var _formKey = GlobalKey<_SchoolFormState>();
  var _bellsKey = GlobalKey<_BellTimesState>();
  bool _saving = false;

  void _resetDraft() {
    _formKey = GlobalKey<_SchoolFormState>();
    _bellsKey = GlobalKey<_BellTimesState>();
  }

  void _changed() => setState(() {});

  bool get _dirty =>
      (_formKey.currentState?.isDirty ?? false) ||
      (_bellsKey.currentState?.isDirty ?? false);

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    final bells = _bellsKey.currentState;
    setState(() => _saving = true);
    try {
      if (form != null && form.isDirty && !await form.save()) return;
      if (bells != null && bells.isDirty && !await bells.save()) return;
      if (!mounted) return;
      ref.invalidate(schoolDataProvider);
      ref.invalidate(schoolWeekProvider);
      context.showMessage(context.l10n.schoolSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    // While a school is being created, "Schule anlegen" in the form is its one save:
    // the bar's "Speichern" is for changes to a school that exists.
    final creating = _adding || (data.value?.schools.isEmpty ?? true);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.schoolSetupTitle),
        actions: [
          if (!creating && (_dirty || _saving))
            TextButton(
              onPressed: _saving || !(_formKey.currentState?.isValid ?? false)
                  ? null
                  : _save,
              child: Text(l10n.save),
            ),
        ],
      ),
      body: ContentWidth(
        child: AbsorbPointer(
          absorbing: _saving,
          child: AsyncValueView(
            value: data,
            onRetry: () => ref.invalidate(schoolDataProvider),
            data: (d) {
              final school = _adding
                  ? null
                  : d.schools.where((s) => s.id == _selectedId).firstOrNull ??
                        d.schools.firstOrNull;
              final first = d.schools.isEmpty;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (school != null && !_adding)
                    _NextSteps(data: d, school: school),
                  if (d.schools.length > 1)
                    _SchoolSwitcher(
                      schools: d.schools,
                      selected: school,
                      onSelected: (id) => setState(() {
                        _resetDraft();
                        _adding = false;
                        _selectedId = id;
                      }),
                    ),
                  // "Weitere Schule" once there is one: above the very first form it
                  // would offer what is already on screen.
                  if (!_adding && !first)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _resetDraft();
                          _adding = true;
                        }),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.schoolsUiAddSchool),
                      ),
                    ),
                  _SchoolForm(
                    key: _formKey,
                    onChanged: _changed,
                    school: school,
                    onCreated: (id) => setState(() {
                      _resetDraft();
                      _adding = false;
                      _selectedId = id;
                    }),
                  ),
                  if (school == null) ...[
                    // The first school, or another one: name and region are all it takes.
                    // Bell times and subjects come as starter content (specs/21).
                    Text(l10n.schoolSetupFirstHint),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey('school-create'),
                      onPressed:
                          _saving || !(_formKey.currentState?.isValid ?? false)
                          ? null
                          : _save,
                      child: Text(l10n.schoolSetupCreate),
                    ),
                    if (first) const SizedBox(height: 24),
                  ],
                  if (school != null) ...[
                    _BellTimes(
                      key: _bellsKey,
                      onChanged: _changed,
                      data: d,
                      school: school,
                    ),
                    _Terms(data: d, school: school),
                    _Holidays(data: d, school: school),
                  ],
                  if (!first) _Subjects(data: d),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What comes after the school exists (specs/24 "Fewer required facts"): the children
/// without a timetable in the current term, each one tap from the editor or the import.
/// Nothing is shown when every child has one.
class _NextSteps extends ConsumerWidget {
  const _NextSteps({required this.data, required this.school});

  final SchoolData data;
  final SchoolRecord school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final today = DateTime.now();
    final term = data.termFor(today, schoolId: school.id);
    final kids = [
      for (final m in members)
        if (m.active &&
            m.isChild &&
            (term == null || data.timetableOf(m.id, term.id) == null) &&
            !data.timetables.any(
              (t) => t.profileId == m.id && t.schoolId == school.id,
            ))
          m,
    ];
    if (kids.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: l10n.schoolNextSteps,
      children: [
        for (final k in kids)
          Card(
            child: ListTile(
              key: ValueKey('next-step-${k.id}'),
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(l10n.schoolNextStepEnter(k.displayName)),
              trailing: TextButton(
                onPressed: () =>
                    showTimetableImportMenu(context, ref, profileId: k.id),
                child: Text(l10n.schoolImportAction),
              ),
              onTap: () => openTimetableEditor(
                context,
                ref,
                data: data,
                profileId: k.id,
                monday: today,
              ),
            ),
          ),
      ],
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
  Future<Result<Object?>> Function(String? actor) action, {
  bool refresh = true,
}) async {
  final result = await action(ref.read(actingProfileProvider));
  if (!context.mounted) return false;
  switch (result) {
    case Err(:final failure):
      context.showFailure(failure);
      return false;
    case Ok():
      if (refresh) {
        ref.invalidate(schoolDataProvider);
        ref.invalidate(schoolWeekProvider);
        context.showMessage(context.l10n.schoolSaved);
      }
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
  const _SchoolForm({
    required this.school,
    required this.onCreated,
    required this.onChanged,
    super.key,
  });

  final SchoolRecord? school;
  final ValueChanged<String> onCreated;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SchoolForm> createState() => _SchoolFormState();
}

class _SchoolFormState extends ConsumerState<_SchoolForm>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final _name = TextEditingController(text: widget.school?.name ?? '');
  late String _savedName = widget.school?.name ?? '';
  late String? _savedRegion = widget.school?.regionCode;

  bool get isValid => _name.text.trim().isNotEmpty;

  bool get isDirty =>
      _name.text.trim() != _savedName || (_touched && _picked != _savedRegion);

  Future<bool> save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return false;
    final settings =
        ref.read(householdSettingsProvider).value ?? const <SettingEntry>[];
    final region = _regionOn(settings);
    final language = Localizations.localeOf(context).languageCode;
    String? savedId;
    final saved = await _write(context, ref, (actor) async {
      final result = await ref
          .read(schoolRepositoryProvider)
          .saveSchool(
            actor: actor,
            id: widget.school?.id,
            name: name,
            regionCode: region,
            // A new school takes the household's timezone on the server.
            timezone: widget.school?.timezone,
            language: language,
          );
      savedId = result.valueOrNull;
      return result;
    }, refresh: false);
    if (!saved || !mounted) return false;
    _savedName = name;
    _savedRegion = region;
    if (region != null) await _proposeHouseholdRegion(region);
    if (!mounted) return false;
    final id = savedId;
    if (widget.school == null && id != null) widget.onCreated(id);
    return true;
  }

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
    super.build(context);
    final l10n = context.l10n;
    final settings =
        ref.watch(householdSettingsProvider).value ?? const <SettingEntry>[];
    return _Section(
      title: widget.school == null
          ? l10n.schoolsUiNewSchool
          : l10n.schoolSectionSchool,
      children: [
        TextField(
          key: const ValueKey('school-name'),
          controller: _name,
          onChanged: (_) => widget.onChanged(),
          decoration: InputDecoration(
            labelText: l10n.schoolName,
            // Why "Schule anlegen" is still off: the name is the one thing missing.
            helperText: widget.school == null && !isValid
                ? l10n.fieldRequired
                : null,
          ),
        ),
        const SizedBox(height: 12),
        RegionField(
          code: _regionOn(settings),
          onChanged: (code) => setState(() {
            _touched = true;
            _picked = code;
            widget.onChanged();
          }),
        ),
      ],
    );
  }
}

/// Bell times in order: a lesson (its index counts up) and the break after it.
class _BellTimes extends ConsumerStatefulWidget {
  const _BellTimes({
    required this.data,
    required this.school,
    required this.onChanged,
    super.key,
  });

  final VoidCallback onChanged;
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

class _BellTimesState extends ConsumerState<_BellTimes>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final List<_BellRow> _rows = [
    for (final p in widget.data.periods.where(
      (p) => p.schoolId == widget.school.id,
    ))
      _BellRow(isBreak: p.isBreak, starts: p.starts, ends: p.ends),
  ];

  List<(bool, TimeOfDay, TimeOfDay)> _snapshot() => [
    for (final row in _rows) (row.isBreak, row.starts, row.ends),
  ];

  late List<(bool, TimeOfDay, TimeOfDay)> _saved;

  @override
  void initState() {
    super.initState();
    // Capture the original rows before the first edit.
    _saved = _snapshot();
  }

  bool get isDirty => !listEquals(_saved, _snapshot());

  Future<bool> save() async {
    final saved = await _write(
      context,
      ref,
      (actor) => ref
          .read(schoolRepositoryProvider)
          .setPeriods(
            actor: actor,
            schoolId: widget.school.id,
            periods: _periods(),
          ),
      refresh: false,
    );
    if (saved && mounted) _saved = _snapshot();
    return saved;
  }

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
      widget.onChanged();
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
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                    onPressed: () => setState(() {
                      _rows.removeAt(i);
                      widget.onChanged();
                    }),
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
            builder: (_) => SchoolTermDialog(schoolId: school.id),
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
                '${context.mediumDate(t.startsOn)} – '
                '${context.mediumDate(t.endsOn)}'
                '${t.isCurrent ? ' · ${l10n.schoolCurrent}' : ''}',
              ),
              onTap: () async {
                final edited = await showDialog<TermRecord>(
                  context: context,
                  builder: (_) =>
                      SchoolTermDialog(schoolId: school.id, term: t),
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

/// Creates or edits a term, optionally before entering a timetable: then the term must
/// cover the week the timetable is for, and the dialog says so next to the date.
class SchoolTermDialog extends StatefulWidget {
  const SchoolTermDialog({
    required this.schoolId,
    this.term,
    this.forTimetableOn,
    this.proposed,
    super.key,
  });

  final String schoolId;
  final TermRecord? term;

  /// The Monday of the week whose timetable is about to be entered.
  final DateTime? forTimetableOn;

  /// A prefilled new term (the school year around the week, specs/24), so one tap
  /// continues. Ignored when [term] is set.
  final TermRecord? proposed;

  @override
  State<SchoolTermDialog> createState() => _SchoolTermDialogState();
}

class _SchoolTermDialogState extends State<SchoolTermDialog> {
  TermRecord? get _given => widget.term ?? widget.proposed;

  late final _name = TextEditingController(text: _given?.name ?? '');
  late final _anchor = TextEditingController(
    text: widget.term?.abAnchorWeek?.toString() ?? '',
  );
  late DateTime _from =
      _given?.startsOn ??
      widget.forTimetableOn ??
      DateUtils.dateOnly(DateTime.now());

  /// Null until chosen or proposed: a term is a range, never silently one day long.
  late DateTime? _to = _given?.endsOn;
  late bool _abWeeks = widget.term?.abAnchorWeek != null;
  late bool _current = _given?.isCurrent ?? false;

  @override
  void dispose() {
    _name.dispose();
    _anchor.dispose();
    super.dispose();
  }

  Future<void> _date({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to ?? _from,
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

  int? get _anchorWeek => int.tryParse(_anchor.text.trim());

  bool get _anchorValid {
    if (!_abWeeks) return true;
    final week = _anchorWeek;
    return week != null && week >= 1 && week <= 53;
  }

  /// The week shown as "19.10. – 25.10.", when the dialog opens from the timetable.
  String? _weekLabel(BuildContext context) {
    final monday = widget.forTimetableOn;
    if (monday == null) return null;
    final sunday = monday.add(const Duration(days: 6));
    return '${context.dayMonth(monday)} – ${context.dayMonth(sunday)}';
  }

  /// The anchor is read in the ISO year the term starts in, so the number of the week
  /// shown only helps when both lie in the same ISO year.
  bool get _shownWeekHelps {
    final monday = widget.forTimetableOn;
    return monday != null && _isoYearOf(monday) == _isoYearOf(_from);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final monday = widget.forTimetableOn;
    final week = _weekLabel(context);
    final fromError = monday != null && monday.isBefore(_from)
        ? l10n.schoolTermMustCoverWeek(week!)
        : null;
    final to = _to;
    final String? toError;
    if (to == null) {
      toError = null;
    } else if (to.isBefore(_from)) {
      toError = l10n.schoolTermEndBeforeStart;
    } else if (monday != null && monday.isAfter(to)) {
      toError = l10n.schoolTermMustCoverWeek(week!);
    } else {
      toError = null;
    }
    final anchorError =
        _abWeeks && _anchor.text.trim().isNotEmpty && !_anchorValid
        ? l10n.schoolAbWeekInvalid
        : null;
    final canSave =
        _name.text.trim().isNotEmpty &&
        to != null &&
        fromError == null &&
        toError == null &&
        _anchorValid;
    return AlertDialog(
      title: Text(
        widget.term == null ? l10n.schoolTermNew : l10n.schoolTermEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (monday != null) ...[
              Text(
                widget.proposed != null && widget.term == null
                    ? l10n.schoolTermProposedHint
                    : l10n.schoolTimetableNeedsTerm,
              ),
              const SizedBox(height: Tokens.space4),
            ],
            TextField(
              controller: _name,
              autofocus: widget.term == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.schoolTermName,
                hintText: l10n.schoolTermNameHint,
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DateField(
                    key: const ValueKey('term-from'),
                    label: l10n.schoolFrom,
                    date: _from,
                    errorText: fromError,
                    onTap: () => _date(from: true),
                  ),
                ),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: _DateField(
                    key: const ValueKey('term-to'),
                    label: l10n.schoolTo,
                    date: to,
                    hint: l10n.schoolTermPickDate,
                    errorText: toError,
                    onTap: () => _date(from: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.schoolAbWeeks),
              subtitle: Text(l10n.schoolAbWeeksHint),
              value: _abWeeks,
              onChanged: (v) => setState(() => _abWeeks = v),
            ),
            if (_abWeeks) ...[
              TextField(
                key: const ValueKey('term-anchor'),
                controller: _anchor,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.schoolAbWeek,
                  helperText: [
                    l10n.schoolAbWeekHint,
                    if (_shownWeekHelps)
                      l10n.schoolAbWeekShown(isoWeekOf(monday!)),
                  ].join(' '),
                  helperMaxLines: 4,
                  errorText: anchorError,
                ),
              ),
              const SizedBox(height: Tokens.space2),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.schoolCurrentTerm),
              subtitle: Text(l10n.schoolCurrentTermHint),
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
          onPressed: !canSave
              ? null
              : () => Navigator.of(context).pop(
                  TermRecord(
                    id: widget.term?.id ?? '',
                    schoolId: widget.schoolId,
                    name: _name.text.trim(),
                    startsOn: _from,
                    endsOn: to,
                    abAnchorWeek: _abWeeks ? _anchorWeek : null,
                    isCurrent: _current,
                  ),
                ),
          child: Text(
            widget.forTimetableOn == null ? l10n.save : l10n.schoolTermContinue,
          ),
        ),
      ],
    );
  }
}

/// A date as a form field: the label stays above, the value or a prompt sits in the
/// box, and a tap opens the picker.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.hint,
    this.errorText,
    super.key,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String? hint;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    // One style for value and prompt, so an empty field is as tall as a filled one.
    final style = Theme.of(context).textTheme.bodyLarge;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        baseStyle: style,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          errorMaxLines: 3,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        isEmpty: date == null,
        child: Text(date == null ? '' : context.mediumDate(date), style: style),
      ),
    );
  }
}

/// The ISO year of [date]: the year of its week's Thursday.
int _isoYearOf(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  return d.add(Duration(days: 4 - d.weekday)).year;
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
                aliases: widget.subject?.aliases ?? const [],
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
