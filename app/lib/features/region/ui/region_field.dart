import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/region/ui/region_label.dart';
import 'package:wuselwall/features/region/ui/region_picker_page.dart';

/// A form field for a region: tapping it opens the picker, and the clear button takes the
/// region off again. [onChanged] receives the new code, or null for no region.
class RegionField extends StatelessWidget {
  const RegionField({
    required this.code,
    required this.onChanged,
    this.label,
    this.showLabel = true,
    super.key,
  });

  final String? code;
  final ValueChanged<String?> onChanged;
  final String? label;

  /// False where a heading above already names the field, such as the setting row
  /// "Region": the label would only repeat it.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = this.code;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final pick = await showRegionPicker(context, current: code);
        if (pick != null) onChanged(pick.code);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: showLabel ? label ?? l10n.regionFieldLabel : null,
          suffixIcon: code == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  tooltip: l10n.regionFieldClear,
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: code == null
            ? Text(l10n.regionFieldEmpty)
            : RegionLabel(code: code),
      ),
    );
  }
}
