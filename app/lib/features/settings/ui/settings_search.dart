import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/search.dart';
import 'package:wuselwall/core/ui/search_field.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/ui/setting_labels.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';

/// One thing the settings search can find (FR-10.1): a group's page, or one row of it.
class SettingsHit {
  const SettingsHit({
    required this.group,
    required this.title,
    required this.help,
    this.item,
    this.section,
    this.advancedOnly = false,
  });

  final SettingsGroup group;

  /// The row; null for the group's page itself.
  final SettingsItem? item;

  /// The heading the row stands under on its page, if that section has one.
  final String? section;
  final String title;

  /// The row's explanation, searched after the title and shown under it.
  final String help;

  /// Only the Advanced view shows this row: choosing it switches the device to Advanced.
  final bool advancedOnly;

  /// Where the hit leads: the group's page, with the row in view.
  String get route => switch (item) {
    null => group.route,
    final item => Routes.settingsRow(group.route, item.rowId),
  };
}

/// Everything the search of Einstellungen looks through on this device: every group that
/// has a page and every row the Advanced view shows there, the rows Basic hides marked
/// ([SettingsHit.advancedOnly]). What this device or person may not open at all is not in
/// it, because [visibleSections] decides both.
List<SettingsHit> settingsSearchIndex(AppLocalizations l10n, SettingsEnv env) {
  final all = env.copyWith(advanced: true);
  final hits = <SettingsHit>[];
  for (final group in visibleGroups(all)) {
    final shown = {
      for (final section in visibleSections(group, env))
        for (final item in section.items) item.rowId,
    };
    hits.add(
      SettingsHit(
        group: group,
        title: group.title(l10n),
        help: group.subtitle(l10n),
        advancedOnly: shown.isEmpty,
      ),
    );
    for (final section in visibleSections(group, all)) {
      final heading = settingsSectionTitle(l10n, section.id);
      for (final item in section.items) {
        final text = switch (item) {
          SettingKey(:final key) => settingText(l10n, key),
          SettingTileItem(:final tile) => settingsTileText(l10n, tile),
        };
        hits.add(
          SettingsHit(
            group: group,
            item: item,
            // A heading that only repeats its row says nothing more.
            section: heading == text.title ? null : heading,
            title: text.title,
            help: text.help,
            advancedOnly: !shown.contains(item.rowId),
          ),
        );
      }
    }
  }
  return hits;
}

/// The hits of [index] that answer [query], best first: the title counts before the
/// section and the group, and those before the explanation.
List<SettingsHit> searchSettings(
  AppLocalizations l10n,
  List<SettingsHit> index,
  String query, {
  int? limit,
}) => searchIn(
  query,
  index,
  (hit) => [hit.title, hit.section, hit.group.title(l10n), hit.help],
  limit: limit,
);

/// Opens what [hit] names. A row only Advanced shows first switches this device to
/// Advanced (the same choice as the chip, kept for the next start), so the page that
/// opens has the row.
Future<void> openSettingsHit(
  BuildContext context,
  WidgetRef ref,
  SettingsHit hit,
) async {
  if (hit.advancedOnly) {
    await ref.read(settingsViewProvider.notifier).select(SettingsView.advanced);
  }
  if (!context.mounted) return;
  context.go(hit.route);
}

/// One search result of Einstellungen: the row's name, where it lives, what it does, and
/// "Advanced" on a row the Basic view hides.
class SettingsHitTile extends ConsumerWidget {
  const SettingsHitTile({required this.hit, super.key});

  final SettingsHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final group = hit.group.title(l10n);
    final where = [if (hit.item != null) group, ?hit.section].join(' › ');
    return ListTile(
      key: ValueKey('settings-hit-${hit.group.name}-${hit.item?.rowId ?? ''}'),
      leading: SearchLeading(child: Icon(hit.group.icon)),
      title: Text(hit.title),
      subtitle: where.isEmpty && hit.help.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (where.isNotEmpty)
                  Text(where, style: theme.textTheme.labelMedium),
                if (hit.help.isNotEmpty)
                  Text(hit.help, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
      trailing: hit.advancedOnly
          ? Text(
              l10n.settingsViewAdvanced,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.ww.ink2,
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => openSettingsHit(context, ref, hit),
    );
  }
}
