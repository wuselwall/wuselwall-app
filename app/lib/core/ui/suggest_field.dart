import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/suggest.dart';

/// A text field that proposes what the family entered before, in a small list under
/// it, while somebody types. A tap, or the arrow keys and Enter, takes one over.
/// Enter alone (the keyboard's Done) never does: what was typed stays, so a new title
/// that begins like an old one is not replaced by it.
///
/// It is an ordinary [TextField] around [controller]; with no [entries] (or an empty
/// field) nothing is proposed and it behaves like the plain field.
class SuggestField extends StatefulWidget {
  const SuggestField({
    required this.controller,
    required this.entries,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.autofocus = false,
    this.onChanged,
    this.onPicked,
    super.key,
  });

  final TextEditingController controller;

  /// What can be proposed; ranked against the text as it is typed.
  final List<TextSuggestion> entries;

  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool autofocus;

  /// Called for typing and for a picked proposal alike.
  final ValueChanged<String>? onChanged;

  /// Called after a proposal was put into the field, with the whole entry (its place
  /// and picture, when it has them).
  final ValueChanged<TextSuggestion>? onPicked;

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  FocusNode? _ownFocus;

  /// Whether the person moved to a proposal with the arrow keys since the text last
  /// changed. Only then is a row highlighted, and only then does Enter take it.
  final _chosen = ValueNotifier<bool>(false);

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void didUpdateWidget(SuggestField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != null && _ownFocus != null) {
      final own = _ownFocus!;
      _ownFocus = null;
      // The old node is still attached to the field of this frame.
      SchedulerBinding.instance.addPostFrameCallback((_) => own.dispose());
    }
  }

  @override
  void dispose() {
    _ownFocus?.dispose();
    _chosen.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _chosen.value = false;
    widget.onChanged?.call(text);
  }

  /// The first arrow key lands on the first proposal (RawAutocomplete already stands
  /// there, unseen); the following ones move as it moves them.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (_chosen.value ||
        rankSuggestions(widget.controller.text, widget.entries).isEmpty) {
      return KeyEventResult.ignored;
    }
    _chosen.value = true;
    return KeyEventResult.handled;
  }

  void _picked(TextSuggestion option) {
    final text = option.text;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _chosen.value = false;
    widget.onChanged?.call(text);
    widget.onPicked?.call(option);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<TextSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (option) => option.text,
      optionsBuilder: (value) => rankSuggestions(value.text, widget.entries),
      onSelected: _picked,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onKey,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: widget.decoration,
              textCapitalization: widget.textCapitalization,
              maxLength: widget.maxLength,
              autofocus: widget.autofocus,
              onChanged: _changed,
              onSubmitted: (_) {
                if (_chosen.value) onFieldSubmitted();
              },
            ),
          ),
      optionsViewBuilder: (context, onSelected, options) => _SuggestOptions(
        options: options.toList(),
        onSelected: onSelected,
        chosen: _chosen,
      ),
    );
  }
}

/// The card under the field. RawAutocomplete sizes it to the field's width.
class _SuggestOptions extends StatefulWidget {
  const _SuggestOptions({
    required this.options,
    required this.onSelected,
    required this.chosen,
  });

  final List<TextSuggestion> options;
  final AutocompleteOnSelected<TextSuggestion> onSelected;

  /// Whether a row is highlighted at all (see [_SuggestFieldState._chosen]).
  final ValueListenable<bool> chosen;

  @override
  State<_SuggestOptions> createState() => _SuggestOptionsState();
}

class _SuggestOptionsState extends State<_SuggestOptions> {
  final _scroll = ScrollController();
  int _highlighted = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(int index) {
    if (index == _highlighted) return;
    _highlighted = index;
    if (index < 0 || index >= widget.options.length) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final row = GlobalObjectKey(widget.options[index]).currentContext;
      if (row != null) {
        Scrollable.ensureVisible(row);
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(index == 0 ? 0 : _scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = AutocompleteHighlightedOption.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: widget.chosen,
      builder: (context, chosen, _) => _list(theme, chosen ? at : -1),
    );
  }

  Widget _list(ThemeData theme, int highlighted) {
    _follow(highlighted);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Semantics(
        container: true,
        label: context.l10n.suggestFieldOptions,
        child: Material(
          // A menu over the form: a line and a soft shadow set it off (specs/17).
          elevation: 3,
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              controller: _scroll,
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final location = option.location;
                return InkWell(
                  key: GlobalObjectKey(option),
                  onTap: () => widget.onSelected(option),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    color: index == highlighted ? theme.focusColor : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(option.text, style: theme.textTheme.bodyLarge),
                        if (location != null && location.isNotEmpty)
                          Text(
                            location,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
