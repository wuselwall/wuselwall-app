import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// Shows a failed write the house way (a snackbar with the failure's message) and says
/// whether it worked.
bool reportTripResult<T>(BuildContext context, Result<T> result) {
  if (!result.isOk && context.mounted) {
    context.showFailure(result.failureOrNull!);
  }
  return result.isOk;
}

/// Awaits [write] and reports a failure the same way; false when it failed.
Future<bool> runTripWrite<T>(
  BuildContext context,
  Future<Result<T>> write,
) async {
  final result = await write;
  if (!result.isOk && context.mounted) {
    context.showFailure(result.failureOrNull!);
  }
  return result.isOk;
}

/// One line of a packing list or of the to-dos: a tick box, the words, and a menu to
/// change or remove it. A ticked line is quieter; nothing counts or earns points.
class TripCheckRow extends StatelessWidget {
  const TripCheckRow({
    required this.check,
    required this.onTick,
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    this.subtitle,
    super.key,
  });

  final TripCheck check;
  final String? subtitle;
  final ValueChanged<bool> onTick;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quiet = check.done;
    return CheckboxListTile(
      key: ValueKey('trip-check-${check.id}'),
      value: check.done,
      onChanged: (v) => onTick(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 0),
      title: Text(
        check.title,
        style: quiet
            ? TextStyle(
                color: context.ww.ink3,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: context.ww.ink2)),
      secondary: PopupMenuButton<bool>(
        key: ValueKey('trip-check-menu-${check.id}'),
        tooltip: l10n.tripPageMore,
        onSelected: (remove) => remove ? onDelete() : onEdit(),
        itemBuilder: (_) => [
          PopupMenuItem(value: false, child: Text(editLabel)),
          PopupMenuItem(value: true, child: Text(l10n.tripPackRemove)),
        ],
      ),
    );
  }
}
