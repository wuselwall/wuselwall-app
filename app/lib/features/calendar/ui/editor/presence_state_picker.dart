import 'package:flutter/material.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';

/// The six presence states, each drawn as the band it will show on the board, in the
/// first chosen attendee's colour. The state is required for a presence event.
class PresenceStatePicker extends StatelessWidget {
  const PresenceStatePicker({
    required this.selected,
    required this.memberColor,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final PresenceState? selected;

  /// The stored member colour the bands take their tint from.
  final Color memberColor;
  final ValueChanged<PresenceState> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final state in PresenceState.values)
              _StateChoice(
                state: state,
                memberColor: memberColor,
                selected: state == selected,
                onTap: () => onChanged(state),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText!, style: TextStyle(color: scheme.error)),
          ),
      ],
    );
  }
}

class _StateChoice extends StatelessWidget {
  const _StateChoice({
    required this.state,
    required this.memberColor,
    required this.selected,
    required this.onTap,
  });

  final PresenceState state;
  final Color memberColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = context.presenceLabel(state);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: SizedBox(
        width: 150,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  width: selected ? 3 : 1,
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: ExcludeSemantics(
                child: PresenceBandView(
                  state: state,
                  memberColor: memberColor,
                  label: label,
                  dense: true,
                  fontSize:
                      Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
