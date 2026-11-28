import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// A list gets a filter field from this many entries on: below it the eye is quicker
/// than the keyboard (the wish picker's rule for recipes, specs/27).
const listFilterFrom = 7;

/// The field every search and list filter of the app types into: a magnifier, a hint
/// that says what is searched, and a way to empty it once it holds text.
///
/// The field keeps its own text unless a [controller] is given. [onChanged] gets the
/// text as typed; folding and matching are the caller's (`core/text/search.dart`).
class SearchField extends StatefulWidget {
  const SearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_textChanged);
      _controller.addListener(_textChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_textChanged);
    _own?.dispose();
    super.dispose();
  }

  // Only the clear button depends on the text.
  void _textChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        // A hint, not a floating label: the field says what it searches while empty
        // and gives the line to the query after that.
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('search-clear'),
                tooltip: context.l10n.searchClear,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

/// The picture before a search result: icons and task pictures differ in size, and in
/// one box the results' titles start on one line.
class SearchLeading extends StatelessWidget {
  const SearchLeading({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: 40, child: Center(child: child));
}
