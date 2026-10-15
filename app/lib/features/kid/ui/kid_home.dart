import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quiet, for the grown-ups: settings, where guardian actions ask for the PIN.
            // Its own row, so it never sits on top of a page's content.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: Tokens.space1,
                  right: Tokens.space1,
                ),
                child: IconButton(
                  tooltip: l10n.settingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  color: context.ww.ink3,
                  onPressed: () => context.go(Routes.settings),
                ),
              ),
            ),
            Expanded(child: body),
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
            const ActingProfileBar(),
          ],
        ),
      ),
    );
  }

  static IconData _icon(KidTab tab) => switch (tab) {
    KidTab.today => Icons.wb_sunny_rounded,
    KidTab.school => Icons.school_rounded,
    KidTab.points => Icons.star_rounded,
    KidTab.shopping => Icons.shopping_basket_rounded,
    KidTab.family => Icons.people_alt_rounded,
  };
}
