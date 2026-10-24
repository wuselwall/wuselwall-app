import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// What Wusel wears, picked by looking at it: Wusel in every outfit, still, the chosen
/// one outlined. Nothing here is earned or locked (specs/25 "Outfits").
class WuselOutfitPicker extends ConsumerWidget {
  const WuselOutfitPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final WuselOutfit selected;
  final ValueChanged<WuselOutfit> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = WuselColors.of(
      context.ww.shade,
      ref.watch(wuselTuftsProvider),
    );
    return Wrap(
      spacing: Tokens.space2,
      runSpacing: Tokens.space2,
      children: [
        for (final outfit in WuselOutfit.values)
          Semantics(
            button: true,
            selected: outfit == selected,
            label: wuselOutfitName(context.l10n, outfit),
            child: Tooltip(
              message: wuselOutfitName(context.l10n, outfit),
              child: InkWell(
                key: ValueKey('wusel-outfit-${outfit.name}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(outfit),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: outfit == selected
                          ? scheme.primary
                          : context.ww.line,
                      width: outfit == selected ? 3 : 1,
                    ),
                  ),
                  // Still: a row of nine moving Wusels would be a lot.
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: Wusel(colors: colors, outfit: outfit, size: 56),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String wuselOutfitName(AppLocalizations l10n, WuselOutfit outfit) =>
    switch (outfit) {
      WuselOutfit.none => l10n.wuselOutfitNone,
      WuselOutfit.party => l10n.wuselOutfitParty,
      WuselOutfit.crown => l10n.wuselOutfitCrown,
      WuselOutfit.wizard => l10n.wuselOutfitWizard,
      WuselOutfit.wreath => l10n.wuselOutfitWreath,
      WuselOutfit.sunglasses => l10n.wuselOutfitSunglasses,
      WuselOutfit.scarf => l10n.wuselOutfitScarf,
      WuselOutfit.headphones => l10n.wuselOutfitHeadphones,
      WuselOutfit.bow => l10n.wuselOutfitBow,
    };
