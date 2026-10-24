import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// Opens the chore editor. Returns true when the chore was saved or archived.
Future<bool?> showTaskEditor(
  BuildContext context, {
  required List<Member> members,
  required TaskDefaults defaults,
  TaskDefinition? existing,
}) => showDialog<bool>(
  context: context,
  builder: (_) => TaskEditorDialog(
    members: members,
    defaults: defaults,
    existing: existing,
  ),
);

/// Definition CRUD for a chore (specs/06, "Chore admin"). Builds a [TaskDraft] and sends
/// it under the guardian gate; a recurring chore is materialised by the repository.
class TaskEditorDialog extends ConsumerStatefulWidget {
  const TaskEditorDialog({
    required this.members,
    required this.defaults,
    this.existing,
    super.key,
  });

  final List<Member> members;
  final TaskDefaults defaults;
  final TaskDefinition? existing;

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

/// The icon choices: `null` first ("no icon"), then the curated set.
final _iconChoices = <String?>[null, ...taskIconKeys];

const _windowChoices = [1, 2, 3, 4, 5, 6, 7, 10, 14];

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _points;
  late String? _icon;
  late TaskKind _kind;
  late TaskRepeat _repeat;
  late Set<int> _weekdays;
  late DateTime _startsOn;
  late int _window;
  late TaskAssignment _assignment;
  late Set<String> _assignees;
  late bool _verification;

  bool _titleError = false;
  final _titleFocus = FocusNode();
  bool _pointsError = false;
  bool _weekdayError = false;
  bool _poolError = false;
  bool _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final today = taskDay(DateTime.now());
    final parsed = taskRepeatOf(e?.rrule);
    _title = TextEditingController(text: e?.title ?? '');
    _kind = e?.kind ?? widget.defaults.kind;
    _points = TextEditingController(
      text: '${e?.points ?? widget.defaults.pointsFor(_kind)}',
    );
    _icon = e?.iconKey;
    // A new chore is a daily one (the starter chores of specs/21 mostly are), so a
    // title alone is enough to save it.
    _repeat = e == null ? TaskRepeat.daily : parsed.repeat;
    _weekdays = e == null
        ? {today.weekday}
        : parsed.weekdays.isEmpty
        ? {e.startsOn.weekday}
        : parsed.weekdays;
    _startsOn = e?.startsOn ?? today;
    _window = e?.windowDays ?? 1;
    // A new chore rotates through the active children; without children it is open
    // for anyone. An existing chore keeps what it has.
    final children = [
      for (final m in widget.members)
        if (m.active && m.isChild) m.id,
    ];
    _assignment =
        e?.assignment ??
        (children.isEmpty ? TaskAssignment.open : TaskAssignment.rotating);
    _assignees = e == null ? children.toSet() : {...e.assigneeIds};
    _verification = e?.requiresVerification ?? widget.defaults.verification;
  }

  @override
  void dispose() {
    _title.dispose();
    _points.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// Validates the form, marking what is wrong. Null when it can be sent.
  TaskDraft? _draft() {
    final l10n = context.l10n;
    final title = _title.text.trim();
    final points = int.tryParse(_points.text.trim());
    final needsDays =
        _repeat == TaskRepeat.weekdays ||
        _repeat == TaskRepeat.weekly ||
        _repeat == TaskRepeat.biweekly;
    final poolOk = switch (_assignment) {
      TaskAssignment.fixed => _assignees.length == 1,
      TaskAssignment.rotating || TaskAssignment.each => _assignees.isNotEmpty,
      TaskAssignment.open => true,
    };
    setState(() {
      _titleError = title.isEmpty;
      _pointsError = points == null || points < 0;
      _weekdayError = needsDays && _weekdays.isEmpty;
      _poolError = !poolOk;
    });
    if (_titleError || _pointsError || _weekdayError || _poolError) {
      // Put the focus on the first problem and say it: the red text is not read out
      // by itself (A8).
      if (_titleError) _titleFocus.requestFocus();
      final message = _titleError
          ? l10n.tasksTitleRequired
          : _pointsError
          ? l10n.tasksPointsInvalid
          : _weekdayError
          ? l10n.tasksWeekdaysRequired
          : l10n.tasksPoolRequired;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          message,
          Directionality.of(context),
        ),
      );
      return null;
    }
    return TaskDraft(
      id: widget.existing?.id,
      title: title,
      iconKey: _icon,
      kind: _kind,
      points: points!,
      rrule: taskRrule(_repeat, weekdays: _weekdays, startDay: _startsOn.day),
      startsOn: _startsOn,
      windowDays: _window,
      assignment: _assignment,
      assigneeIds: _assignment == TaskAssignment.open
          ? const []
          : _assignees.toList(),
      requiresVerification: _verification,
      isActive: true,
    );
  }

  Future<void> _save() async {
    final draft = _draft();
    if (draft == null) return;
    setState(() => _busy = true);
    final allowed = await ensureGuardian(context, ref);
    if (!mounted) return;
    if (!allowed) {
      setState(() => _busy = false);
      return;
    }
    final result = await ref
        .read(tasksRepositoryProvider)
        .saveDefinition(actor: ref.read(actingProfileProvider), draft: draft);
    invalidateTasks(ref.invalidate);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context, true);
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  Future<void> _archive() async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.tasksArchiveHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.tasksArchive),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final allowed = await ensureGuardian(context, ref);
    if (!mounted || !allowed) return;
    final result = await ref
        .read(tasksRepositoryProvider)
        .archiveDefinition(
          actor: ref.read(actingProfileProvider),
          id: widget.existing!.id,
        );
    invalidateTasks(ref.invalidate);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context, true);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  void _setKind(TaskKind kind) => setState(() {
    _kind = kind;
    _points.text = '${widget.defaults.pointsFor(kind)}';
  });

  void _setRepeat(TaskRepeat repeat) => setState(() {
    _repeat = repeat;
    _weekdayError = false;
  });

  void _toggleWeekday(int day) => setState(() {
    final single =
        _repeat == TaskRepeat.weekly || _repeat == TaskRepeat.biweekly;
    if (single) {
      _weekdays = {day};
    } else {
      _weekdays = _weekdays.contains(day)
          ? (Set.of(_weekdays)..remove(day))
          : (Set.of(_weekdays)..add(day));
    }
  });

  void _toggleAssignee(String id) => setState(() {
    if (_assignment == TaskAssignment.fixed) {
      _assignees = {id};
    } else {
      _assignees = _assignees.contains(id)
          ? (Set.of(_assignees)..remove(id))
          : (Set.of(_assignees)..add(id));
    }
  });

  Future<void> _pickStart() async {
    final today = taskDay(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startsOn = taskDay(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = widget.members.where((m) => m.active).toList();
    // Full screen on a phone and a laptop alike: the form scrolls inside its frame,
    // and the save bar stays in reach.
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_editing ? l10n.tasksEditChore : l10n.tasksNewChore),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space3),
            child: Row(
              children: [
                if (_editing)
                  TextButton.icon(
                    onPressed: _busy ? null : _archive,
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(l10n.tasksArchive),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: Tokens.space2),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Tokens.space4,
            children: [
              TextField(
                controller: _title,
                focusNode: _titleFocus,
                autofocus: !_editing,
                maxLength: 80,
                onChanged: (_) => setState(() => _titleError = false),
                decoration: InputDecoration(
                  labelText: l10n.tasksFieldTitle,
                  errorText: _titleError ? l10n.tasksTitleRequired : null,
                ),
              ),
              _Label(l10n.tasksFieldIcon),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final key in _iconChoices)
                    _IconChoice(
                      asset: taskIconAsset(key),
                      selected: _icon == key,
                      tooltip: key == null
                          ? l10n.tasksNoIcon
                          : taskIconName(l10n, key),
                      onTap: () => setState(() => _icon = key),
                    ),
                ],
              ),
              _Label(l10n.tasksFieldKind),
              SegmentedButton<TaskKind>(
                segments: [
                  ButtonSegment(
                    value: TaskKind.duty,
                    label: Text(l10n.tasksKindDuty),
                  ),
                  ButtonSegment(
                    value: TaskKind.bonus,
                    label: Text(l10n.tasksKindBonus),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => _setKind(s.first),
              ),
              Text(
                _kind == TaskKind.bonus
                    ? l10n.tasksKindBonusHelp
                    : l10n.tasksKindDutyHelp,
              ),
              TextField(
                controller: _points,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _pointsError = false),
                decoration: InputDecoration(
                  labelText: l10n.tasksFieldPoints,
                  errorText: _pointsError ? l10n.tasksPointsInvalid : null,
                ),
              ),
              _Label(l10n.tasksFieldRepeat),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final r in TaskRepeat.values)
                    ChoiceChip(
                      label: Text(_repeatLabel(l10n, r)),
                      selected: _repeat == r,
                      onSelected: (_) => _setRepeat(r),
                    ),
                ],
              ),
              if (_repeat != TaskRepeat.once &&
                  _repeat != TaskRepeat.daily &&
                  _repeat != TaskRepeat.monthly)
                Wrap(
                  spacing: Tokens.space2,
                  runSpacing: Tokens.space2,
                  children: [
                    for (var i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(
                          context.weekdayShort(DateTime(2024, 1, 1 + i)),
                        ),
                        selected: _weekdays.contains(i + 1),
                        onSelected: (_) => _toggleWeekday(i + 1),
                      ),
                  ],
                ),
              if (_weekdayError)
                Text(
                  l10n.tasksWeekdaysRequired,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.tasksFieldStarts}: '
                      '${context.fullDate(_startsOn)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickStart,
                    child: Text(l10n.tasksFieldStarts),
                  ),
                ],
              ),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.tasksFieldWindow,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButton<int>(
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  value: _window,
                  items: [
                    for (final d in {
                      ..._windowChoices,
                      _window,
                    }.toList()..sort())
                      DropdownMenuItem(
                        value: d,
                        child: Text(l10n.tasksWindowDays(d)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _window = v ?? 1),
                ),
              ),
              _Label(l10n.tasksFieldWho),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final a in TaskAssignment.values)
                    ChoiceChip(
                      label: Text(_assignmentLabel(l10n, a)),
                      selected: _assignment == a,
                      onSelected: (_) => setState(() {
                        _assignment = a;
                        _poolError = false;
                        if (a == TaskAssignment.fixed &&
                            _assignees.length > 1) {
                          _assignees = {_assignees.first};
                        }
                      }),
                    ),
                ],
              ),
              if (_assignment != TaskAssignment.open)
                Text(
                  _assignment == TaskAssignment.fixed
                      ? l10n.tasksPickOne
                      : l10n.tasksPickPool,
                )
              else
                Text(l10n.tasksPickOpenPool),
              if (_assignment != TaskAssignment.open)
                Wrap(
                  spacing: Tokens.space2,
                  runSpacing: Tokens.space2,
                  children: [
                    for (final m in active)
                      FilterChip(
                        showCheckmark: false,
                        avatar: RingedAvatar(
                          selected: _assignees.contains(m.id),
                          child: TaskAvatar(
                            name: m.displayName,
                            color: m.color,
                            size: 22,
                          ),
                        ),
                        label: Text(m.displayName),
                        selected: _assignees.contains(m.id),
                        onSelected: (_) => _toggleAssignee(m.id),
                      ),
                  ],
                ),
              if (_poolError && _assignment != TaskAssignment.open)
                Text(
                  l10n.tasksPoolRequired,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.tasksFieldVerification),
                subtitle: Text(l10n.tasksVerificationHelp),
                value: _verification,
                onChanged: (v) => setState(() => _verification = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatLabel(AppLocalizations l10n, TaskRepeat r) => switch (r) {
    TaskRepeat.once => l10n.tasksRepeatOnce,
    TaskRepeat.daily => l10n.tasksRepeatDaily,
    TaskRepeat.weekdays => l10n.tasksRepeatWeekdays,
    TaskRepeat.weekly => l10n.tasksRepeatWeekly,
    TaskRepeat.biweekly => l10n.tasksRepeatBiweekly,
    TaskRepeat.monthly => l10n.tasksRepeatMonthly,
  };

  String _assignmentLabel(AppLocalizations l10n, TaskAssignment a) =>
      switch (a) {
        TaskAssignment.fixed => l10n.tasksWhoFixed,
        TaskAssignment.rotating => l10n.tasksWhoRotating,
        TaskAssignment.open => l10n.tasksWhoOpen,
        TaskAssignment.each => l10n.tasksWhoEach,
      };
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.asset,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final String? asset;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: asset == null
                ? Icon(Icons.block, color: scheme.onSurfaceVariant)
                : EmojiPicture(asset!, size: 28),
          ),
        ),
      ),
    );
  }
}
