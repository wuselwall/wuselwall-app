import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/region/application/region_providers.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';
import 'package:wuselwall/features/region/ui/region_text.dart';

/// A region code as its name: "Uster (Gemeinde), Kanton Zürich (ZH)". While the regions of the
/// code's country load, or when the code is not cached, the bare code is shown.
class RegionLabel extends ConsumerWidget {
  const RegionLabel({required this.code, this.style, super.key});

  final String code;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = code.split('-').first;
    final regions = ref.watch(countryRegionsProvider(country)).value;
    final text = regions == null
        ? code
        : regionLabel(
            context.l10n,
            RegionIndex(regions),
            code,
            languageOf(context),
          );
    return Text(text, style: style);
  }
}
