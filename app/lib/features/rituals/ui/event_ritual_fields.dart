import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/calendar/ui/editor/event_draft.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';

/// The event editor's part of a lighter day (specs/27): a picture, "Darauf freuen wir
/// uns", and whether it is one of the family's traditions, with its meal.
class EventRitualFields extends StatefulWidget {
  const EventRitualFields({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final EventDraft draft;
  final VoidCallback onChanged;

  @override
  State<EventRitualFields> createState() => _EventRitualFieldsState();
}

class _EventRitualFieldsState extends State<EventRitualFields> {
  late final _meal = TextEditingController(text: widget.draft.traditionMeal);

  @override
  void dispose() {
    _meal.dispose();
    super.dispose();
  }

  void _change(void Function(EventDraft d) apply) {
    apply(widget.draft);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = widget.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Tokens.space2),
        Text(l10n.eventIconLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: Tokens.space2),
        Wrap(
          spacing: Tokens.space1,
          runSpacing: Tokens.space1,
          children: [
            _IconChoice(
              tooltip: l10n.eventIconNone,
              selected: d.iconKey == null,
              onTap: () => _change((d) => d.iconKey = null),
              child: const Icon(Icons.block, size: 22),
            ),
            for (final key in eventIconKeys)
              _IconChoice(
                key: ValueKey('event-icon-$key'),
                tooltip: eventIconName(l10n, key),
                selected: d.iconKey == key,
                onTap: () => _change((d) => d.iconKey = key),
                child: EmojiPicture(eventIconAsset(key)!, size: 28),
              ),
          ],
        ),
        SwitchListTile(
          key: const ValueKey('event-countdown'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.eventCountdownTitle),
          subtitle: Text(l10n.eventCountdownHelp),
          value: d.countdown,
          onChanged: (v) => _change((d) => d.countdown = v),
        ),
        SwitchListTile(
          key: const ValueKey('event-tradition'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.eventTraditionTitle),
          subtitle: Text(l10n.eventTraditionHelp),
          value: d.tradition,
          onChanged: (v) => _change((d) => d.tradition = v),
        ),
        if (d.tradition) ...[
          TextField(
            key: const ValueKey('event-tradition-meal'),
            controller: _meal,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.eventTraditionMeal,
              hintText: l10n.eventTraditionMealHint,
            ),
            onChanged: (v) => _change((d) => d.traditionMeal = v),
          ),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'lunch', label: Text(l10n.mealsSlotLunch)),
              ButtonSegment(value: 'dinner', label: Text(l10n.mealsSlotDinner)),
            ],
            selected: {d.traditionMealSlot == 'lunch' ? 'lunch' : 'dinner'},
            onSelectionChanged: (s) =>
                _change((d) => d.traditionMealSlot = s.first),
          ),
        ],
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? scheme.primaryContainer : null,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
  }
}
