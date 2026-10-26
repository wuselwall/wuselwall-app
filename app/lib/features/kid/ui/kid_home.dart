import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_family_page.dart';
import 'package:wuselwall/features/kid/ui/kid_picker.dart';
import 'package:wuselwall/features/kid/ui/kid_points_page.dart';
import 'package:wuselwall/features/kid/ui/kid_timetable_page.dart';
import 'package:wuselwall/features/kid/ui/kid_today_page.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/settings/application/settings_access.dart';
import 'package:wuselwall/features/settings/ui/open_settings.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

/// The children's iPad (specs/09 "Screens by register"): five big destinations, icons
/// first, and the avatar bar at the bottom to say who is holding the device. No
/// destructive action; settings only behind a quiet gear, guarded by the PIN there. Without an acting child, the first three tabs are
/// replaced by the picker; shopping and family stay open to everyone.
class KidHome extends ConsumerWidget {
  const KidHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tab = ref.watch(kidTabProvider);
    final actor = ref.watch(actingProfileProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final member = members.where((m) => m.id == actor).firstOrNull;

    final body = switch (tab) {
      KidTab.shopping => const ShoppingBody(),
      KidTab.family => const KidFamilyPage(),
      _ when member == null => const KidPicker(),
      KidTab.today => KidTodayPage(
        key: ValueKey('today-${member.id}'),
        member: member,
      ),
      KidTab.school => KidTimetablePage(
        key: ValueKey('school-${member.id}'),
        actor: member.id,
      ),
      KidTab.points => KidPointsPage(
        key: ValueKey('points-${member.id}'),
        actor: member.id,
      ),
    };

    final picking =
        member == null && tab != KidTab.shopping && tab != KidTab.family;
    final band = context.ww.band(_module(tab));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quiet, for the grown-ups: settings, where guardian actions ask for the PIN.
            // Its own row, so it never sits on top of a page's content. The row is the
            // tab's band (specs/26), so each destination has its colour.
            ColoredBox(
              color: band,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: Tokens.space1,
                    right: Tokens.space1,
                  ),
                  // A family tablet with nobody selected has no gear (specs/09); the row
                  // keeps its height so nothing jumps when someone picks their name.
                  child: ref.watch(settingsGearVisibleProvider)
                      ? IconButton(
                          tooltip: l10n.settingsTitle,
                          icon: const Icon(Icons.settings_outlined),
                          // ink2: ink3 is not used on a band (specs/26).
                          color: context.ww.ink2,
                          onPressed: () =>
                              unawaited(openSettings(context, ref)),
                        )
                      : const SizedBox.square(
                          dimension: kMinInteractiveDimension,
                        ),
                ),
              ),
            ),
            Expanded(
              child: KidDecorScope(decor: _decor(tab), child: body),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  indicatorColor: band,
                  labelTextStyle: WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: Tokens.fontUi,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  iconTheme: const WidgetStatePropertyAll(
                    IconThemeData(size: 32),
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: tab.index,
                onDestinationSelected: (i) =>
                    ref.read(kidTabProvider.notifier).select(KidTab.values[i]),
                destinations: [
                  NavigationDestination(
                    icon: Icon(_icon(KidTab.today)),
                    label: l10n.kidTabToday,
                  ),
                  NavigationDestination(
                    icon: Icon(_icon(KidTab.school)),
                    label: l10n.kidTabSchool,
                  ),
                  NavigationDestination(
                    icon: Icon(_icon(KidTab.points)),
                    label: l10n.kidTabPoints,
                  ),
                  NavigationDestination(
                    icon: Icon(_icon(KidTab.shopping)),
                    label: l10n.kidTabShopping,
                  ),
                  NavigationDestination(
                    icon: Icon(_icon(KidTab.family)),
                    label: l10n.kidTabFamily,
                  ),
                ],
              ),
            ),
            // While the big picker fills the page it is the one place to say who is
            // here; the bar below would only repeat it.
            if (!picking) const ActingProfileBar(),
          ],
        ),
      ),
    );
  }

  /// The band of each kid destination: the same colours as the adult modules, so a
  /// child learns "yellow is my day" once (specs/26).
  static AppModule _module(KidTab tab) => switch (tab) {
    KidTab.today => AppModule.today,
    KidTab.school => AppModule.schedule,
    KidTab.points => AppModule.tasks,
    KidTab.shopping => AppModule.shopping,
    KidTab.family => AppModule.calendar,
  };

  /// The offset shadows of the tab's cards.
  static Decor _decor(KidTab tab) => switch (tab) {
    KidTab.today => Decor.sun,
    KidTab.school => Decor.lilac,
    KidTab.points => Decor.coral,
    KidTab.shopping => Decor.mint,
    KidTab.family => Decor.sky,
  };

  static IconData _icon(KidTab tab) => switch (tab) {
    KidTab.today => Icons.wb_sunny_rounded,
    KidTab.school => Icons.school_rounded,
    KidTab.points => Icons.star_rounded,
    KidTab.shopping => Icons.shopping_basket_rounded,
    KidTab.family => Icons.people_alt_rounded,
  };
}
