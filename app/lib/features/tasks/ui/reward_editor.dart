import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// Opens the reward editor. Returns true when the reward was saved.
Future<bool?> showRewardEditor(
  BuildContext context, {
  required TaskDefaults defaults,
  Reward? existing,
}) => showDialog<bool>(
  context: context,
  builder: (_) => RewardEditorDialog(defaults: defaults, existing: existing),
);

/// The reward catalogue's editor (specs/06, "Rewards"). Cost is in points; stock is
/// optional; approval defaults to the household's setting.
class RewardEditorDialog extends ConsumerStatefulWidget {
  const RewardEditorDialog({required this.defaults, this.existing, super.key});

  final TaskDefaults defaults;
  final Reward? existing;

  @override
  ConsumerState<RewardEditorDialog> createState() => _RewardEditorDialogState();
}

class _RewardEditorDialogState extends ConsumerState<RewardEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _cost;
  late final TextEditingController _stock;
  late String? _icon;
  late bool _approval;
  bool _titleError = false;
  bool _costError = false;
  bool _stockError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _cost = TextEditingController(text: '${e?.costPoints ?? 5}');
    _stock = TextEditingController(text: e?.stock?.toString() ?? '');
    _icon = e?.iconKey;
    _approval = e?.requiresApproval ?? widget.defaults.rewardRequiresApproval;
  }

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final cost = int.tryParse(_cost.text.trim());
    final stockText = _stock.text.trim();
    final stock = stockText.isEmpty ? null : int.tryParse(stockText);
    setState(() {
      _titleError = title.isEmpty;
      _costError = cost == null || cost <= 0;
      _stockError = stockText.isNotEmpty && (stock == null || stock < 0);
    });
    if (_titleError || _costError || _stockError) return;

    setState(() => _busy = true);
    final allowed = await ensureGuardian(context, ref);
    if (!mounted) return;
    if (!allowed) {
      setState(() => _busy = false);
      return;
    }
    final result = await ref
        .read(tasksRepositoryProvider)
        .saveReward(
          actor: ref.read(actingProfileProvider),
          draft: RewardDraft(
            id: widget.existing?.id,
            title: title,
            iconKey: _icon,
            costPoints: cost!,
            stock: stock,
            requiresApproval: _approval,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Tokens.space4,
            children: [
              Text(
                widget.existing == null
                    ? l10n.tasksNewReward
                    : l10n.tasksEditReward,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextField(
                controller: _title,
                autofocus: widget.existing == null,
                maxLength: 80,
                onChanged: (_) => setState(() => _titleError = false),
                decoration: InputDecoration(
                  labelText: l10n.tasksFieldTitle,
                  errorText: _titleError ? l10n.tasksTitleRequired : null,
                ),
              ),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final key in <String?>[null, ...taskIcons.keys])
                    ChoiceChip(
                      label: Text(taskIconGlyph(key) ?? l10n.tasksNoIcon),
                      selected: _icon == key,
                      onSelected: (_) => setState(() => _icon = key),
                    ),
                ],
              ),
              TextField(
                controller: _cost,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _costError = false),
                decoration: InputDecoration(
                  labelText: l10n.tasksFieldCost,
                  errorText: _costError ? l10n.tasksPointsInvalid : null,
                ),
              ),
              TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _stockError = false),
                decoration: InputDecoration(
                  labelText: l10n.tasksFieldStock,
                  errorText: _stockError ? l10n.tasksPointsInvalid : null,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.tasksFieldNeedsApproval),
                subtitle: Text(
                  _approval ? '' : l10n.tasksNeedsApprovalHelp,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                value: _approval,
                onChanged: (v) => setState(() => _approval = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
            ],
          ),
        ),
      ),
    );
  }
}
