import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/ui/delete_account_tile.dart';
import 'package:wuselwall/features/household/ui/leave_family_tiles.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/rituals/ui/table_question_widgets.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/settings/ui/account_sections.dart';
import 'package:wuselwall/features/settings/ui/appearance_tile.dart';
import 'package:wuselwall/features/settings/ui/devices_section.dart';
import 'package:wuselwall/features/settings/ui/help_tiles.dart';
import 'package:wuselwall/features/settings/ui/language_tile.dart';
import 'package:wuselwall/features/settings/ui/learned_words_section.dart';
import 'package:wuselwall/features/settings/ui/server_section.dart';
import 'package:wuselwall/features/settings/ui/setting_controls.dart';
import 'package:wuselwall/features/settings/ui/setting_labels.dart';
import 'package:wuselwall/features/settings/ui/settings_bar_title.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';

/// One group of Einstellungen (specs/21): its sections of catalogue settings and other
/// rows, as [settingsGroupSections] lays them out and this device's view allows. Household
/// and device settings are guardian actions; a member's own settings are not.
///
/// The page stands on its own: [parentRoute] is where Back leads, [showViewSwitch]
/// leaves out the Basic/Advanced chip, and [title] and [subtitle] name the page, so a
/// device that shows one group only (a member's own page on a shared device) can reuse it.
class SettingsGroupPage extends ConsumerWidget {
  const SettingsGroupPage({
    required this.group,
    this.parentRoute = Routes.settings,
    this.showViewSwitch = true,
    this.title,
    this.subtitle,
    this.focusRow,
    super.key,
  });

  final SettingsGroup group;

  /// The row a search result led here for ([SettingsItem.rowId], the link's `row`): the
  /// page scrolls to it and marks it for a moment. Null, or a row this device does not
  /// show, changes nothing.
  final String? focusRow;
  final String parentRoute;
  final bool showViewSwitch;

  /// Replaces the group's own title, such as "Einstellungen" on a person's own page.
  final String? title;

  /// A second line under the title, such as the person's name on their own page.
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final env = ref.watch(settingsEnvProvider);
    final settings = ref.watch(householdSettingsProvider);
    final sections = visibleSections(group, env);
    final hasSettings = [
      for (final section in settingsGroupSections[group]!) ...section.items,
    ].any((item) => item is SettingKey);

    return PopScope<Object?>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(parentRoute);
      },
      child: Scaffold(
        appBar: AppBar(
          title: SettingsBarTitle(
            title: title ?? group.title(l10n),
            shortTitle: title == null ? group.shortTitle(l10n) : null,
            subtitle: subtitle,
          ),
          leading: BackButton(onPressed: () => context.go(parentRoute)),
          actions: [if (showViewSwitch) const SettingsViewSwitch()],
        ),
        body: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            // A list builds only what is near the screen, and a row that is not built
            // cannot be scrolled to: with a row to show, the whole page is built.
            scrollCacheExtent: focusRow == null
                ? null
                : const ScrollCacheExtent.pixels(_wholePage),
            children: [
              if (hasSettings && settings.isLoading && !settings.hasValue)
                const LinearProgressIndicator(),
              if (hasSettings && settings.hasError && !settings.hasValue)
                ErrorView(
                  error: settings.error!,
                  onRetry: () => ref.invalidate(householdSettingsProvider),
                ),
              if (group == SettingsGroup.personal && env.acting == null)
                Text(l10n.settingPickPersonFirst),
              for (final (i, section) in sections.indexed) ...[
                _SectionHeader(title: _headingOf(l10n, section), first: i == 0),
                for (final item in section.items)
                  _FocusedRow(
                    key: ValueKey('settings-row-${item.rowId}'),
                    focused: item.rowId == focusRow,
                    child: switch (item) {
                      SettingKey(:final key) => _SettingRowItem(
                        settingKey: key,
                      ),
                      SettingTileItem(:final tile) => _tileWidget(tile),
                    },
                  ),
              ],
              if (hasHiddenSettings(env, group: group))
                const MoreSettingsHint(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Far more than any group page is long, so [SettingsGroupPage.focusRow] is always built.
const _wholePage = 20000.0;

/// How far the tint of the row in focus reaches beyond the row: half the page's padding.
const _tintOutset = Tokens.space2;

/// A row of the page. The one a search result named ([focused]) is brought into view
/// when the page opens and tinted for a moment, so the eye finds it among its neighbours;
/// where motion is off (specs/26) it is there at once and the tint stays.
class _FocusedRow extends StatefulWidget {
  const _FocusedRow({required this.focused, required this.child, super.key});

  final bool focused;
  final Widget child;

  @override
  State<_FocusedRow> createState() => _FocusedRowState();
}

class _FocusedRowState extends State<_FocusedRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _fade;

  @override
  void initState() {
    super.initState();
    if (!widget.focused) return;
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final moves = motionAllowed(context);
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.2,
          duration: moves ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOut,
        ),
      );
      if (moves) unawaited(_fade!.forward());
    });
  }

  @override
  void dispose() {
    _fade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    if (fade == null) return widget.child;
    final tint = Theme.of(context).colorScheme.secondaryContainer;
    // The tint reaches a little beyond the row on every side, into the page's own
    // padding, so the row's text does not touch its edge; the row itself stays where its
    // neighbours are.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_tintOutset,
          right: -_tintOutset,
          top: -_tintOutset / 2,
          bottom: -_tintOutset / 2,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: fade,
              builder: (context, _) => DecoratedBox(
                key: const ValueKey('settings-row-focused'),
                decoration: BoxDecoration(
                  // Full for the first two thirds, then gone.
                  color: tint.withValues(
                    alpha: 1 - const Interval(0.66, 1).transform(fade.value),
                  ),
                  borderRadius: BorderRadius.circular(Tokens.space2),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// The heading of [section], or null when its first row already says the same ("Wusel"
/// above the setting "Wusel"): a heading that only repeats its row is noise.
String? _headingOf(AppLocalizations l10n, VisibleSection section) {
  final heading = settingsSectionTitle(l10n, section.id);
  if (heading == null) return null;
  final first = section.items.firstOrNull;
  if (first case SettingKey(:final key)
      when settingText(l10n, key).title == heading) {
    return null;
  }
  return heading;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.first});

  final String? title;
  final bool first;

  @override
  Widget build(BuildContext context) {
    if (title == null) {
      return first
          ? const SizedBox.shrink()
          : const SizedBox(height: Tokens.space4);
    }
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : Tokens.space4,
        bottom: Tokens.space2,
      ),
      child: Semantics(
        header: true,
        child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// The widget of a row that is not a catalogue setting.
Widget _tileWidget(SettingsTile tile) => switch (tile) {
  SettingsTile.familyProfile => const _NavTile(
    tile: SettingsTile.familyProfile,
    tileKey: 'settings-family',
    icon: Icons.family_restroom_outlined,
    route: Routes.familyProfile,
    basicSubtitle: _familyProfileSubtitleBasic,
  ),
  SettingsTile.members => const _NavTile(
    tile: SettingsTile.members,
    tileKey: 'settings-members',
    icon: Icons.groups_outlined,
    route: Routes.settingsMembers,
  ),
  SettingsTile.baselines => const _NavTile(
    tile: SettingsTile.baselines,
    tileKey: 'settings-baselines',
    icon: Icons.home_outlined,
    route: Routes.baselines,
  ),
  SettingsTile.reminders => const _NavTile(
    tile: SettingsTile.reminders,
    tileKey: 'settings-reminders',
    icon: Icons.notifications_outlined,
    route: Routes.reminders,
  ),
  SettingsTile.feedTokens => const _NavTile(
    tile: SettingsTile.feedTokens,
    tileKey: 'settings-feeds',
    icon: Icons.rss_feed,
    route: Routes.feedTokens,
  ),
  SettingsTile.externalCalendars => const _NavTile(
    tile: SettingsTile.externalCalendars,
    tileKey: 'settings-external-calendars',
    icon: Icons.cloud_download_outlined,
    route: Routes.externalCalendars,
  ),
  SettingsTile.services => const _NavTile(
    tile: SettingsTile.services,
    tileKey: 'settings-services',
    icon: Icons.cloud_queue_outlined,
    route: Routes.servicesSettings,
  ),
  SettingsTile.familyQuestions => const FamilyQuestionsTile(),
  SettingsTile.language => const LanguageTile(),
  SettingsTile.appearance => const AppearanceTile(),
  SettingsTile.devices => const DevicesSection(),
  SettingsTile.signInMethods => const SignInMethodsSection(),
  SettingsTile.security => const SecuritySection(),
  SettingsTile.leaveFamily => const LeaveFamilyTile(),
  SettingsTile.deleteAccount => const DeleteAccountTile(),
  SettingsTile.server => const ServerSection(),
  SettingsTile.learnedWords => const LearnedWordsSection(),
  SettingsTile.gettingStarted => const GettingStartedTile(),
  SettingsTile.versions => const VersionsTile(),
  SettingsTile.licences => const LicencesTile(),
};

String _familyProfileSubtitleBasic(AppLocalizations l10n) =>
    l10n.familySettingsSubtitleBasic;

/// A row that opens another settings page, titled as [settingsTileText] says.
/// [basicSubtitle] names what that page shows in Basic, where it shows less.
class _NavTile extends ConsumerWidget {
  const _NavTile({
    required this.tile,
    required this.tileKey,
    required this.icon,
    required this.route,
    this.basicSubtitle,
  });

  final SettingsTile tile;
  final String tileKey;
  final IconData icon;
  final String route;
  final String Function(AppLocalizations l10n)? basicSubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final basic = basicSubtitle;
    final advanced = ref.watch(settingsEnvProvider).advanced;
    final text = settingsTileText(l10n, tile);
    return ListTile(
      key: ValueKey(tileKey),
      // The page already pads 16 px: flush, the icon and chevron line up with the
      // headings and the setting rows, as "Unsere Fragen" does.
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(text.title),
      subtitle: Text(basic == null || advanced ? text.help : basic(l10n)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(route),
    );
  }
}

/// The row for one catalogue key as seen by the current device or acting person. Nothing
/// when the target is unknown (no device yet, or nobody at a shared device).
class _SettingRowItem extends ConsumerWidget {
  const _SettingRowItem({required this.settingKey});

  final String settingKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(settingsEnvProvider);
    final definition = env.resolve(settingKey);
    if (definition == null) return const SizedBox.shrink();
    final isMember = definition.scope == SettingScope.member;
    final isDevice = definition.scope == SettingScope.device;
    if (isMember && env.acting == null) return const SizedBox.shrink();
    if (isDevice && env.deviceId == null) return const SizedBox.shrink();

    final profileId = isMember ? env.acting : null;
    final scopedDeviceId = isDevice ? env.deviceId : null;
    final entry = resolveSetting(
      env.entries,
      settingKey,
      profileId: profileId,
      deviceId: scopedDeviceId,
    );
    if (entry == null) return const SizedBox.shrink();

    return SettingRow(
      entry: entry,
      country: env.country,
      onChanged: (value) => _save(
        context,
        ref,
        definition,
        profileId: profileId,
        deviceId: scopedDeviceId,
        value: value,
      ),
      onReset: entry.isDefault
          ? null
          : () => _reset(
              context,
              ref,
              definition,
              profileId: profileId,
              deviceId: scopedDeviceId,
            ),
    );
  }
}

/// Writes one setting. Household and device scopes need a guardian (PIN step-up on
/// shared devices); a member's own settings go through without one.
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  SettingEntry definition, {
  required String? profileId,
  required String? deviceId,
  required Object? value,
}) async {
  if (definition.scope != SettingScope.member &&
      !await ensureGuardian(context, ref)) {
    return;
  }
  if (!context.mounted) return;
  final result = await ref
      .read(householdSettingsRepositoryProvider)
      .set(
        actor: ref.read(actingProfileProvider),
        key: definition.key,
        value: value,
        profileId: profileId,
        deviceId: deviceId,
      );
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      ref.invalidate(householdSettingsProvider);
    case Err(:final failure):
      context.showMessage(failure.message(context.l10n));
  }
}

/// Removes an override (or, for the household row, sets the default back).
Future<void> _reset(
  BuildContext context,
  WidgetRef ref,
  SettingEntry definition, {
  required String? profileId,
  required String? deviceId,
}) async {
  if (definition.scope != SettingScope.member &&
      !await ensureGuardian(context, ref)) {
    return;
  }
  if (!context.mounted) return;
  final result = await ref
      .read(householdSettingsRepositoryProvider)
      .reset(
        actor: ref.read(actingProfileProvider),
        key: definition.key,
        profileId: profileId,
        deviceId: deviceId,
      );
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      ref.invalidate(householdSettingsProvider);
    case Err(:final failure):
      context.showMessage(failure.message(context.l10n));
  }
}
