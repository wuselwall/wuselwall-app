import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/ui/week_board_page.dart';
import 'package:wuselwall/features/calendar/ui/calendar_section.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/kid/ui/kid_home.dart';
import 'package:wuselwall/features/meals/ui/meals_section.dart';
import 'package:wuselwall/features/school/ui/schedule_section.dart';
import 'package:wuselwall/features/shopping/ui/shopping_section.dart';
import 'package:wuselwall/features/tasks/ui/tasks_section.dart';
import 'package:wuselwall/features/today/ui/today_section.dart';

/// Home for every register (specs/09 "Screens by register"). The adult home has one tab
/// per module, each a [HomeSection] owned by its feature. The kid
/// home is [KidHome] (features/kid). The kiosk shows the week board
/// (specs/09 "The week board") with no app bar and no navigation, and reverts to nobody
/// after 60 s idle. Nothing in the kiosk is smaller than 24 px.
class RegisterHomePage extends ConsumerWidget {
  const RegisterHomePage({required this.register, super.key});

  final UiRegister register;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (register == UiRegister.kiosk) {
      return const IdleReverter(
        child: Scaffold(body: SafeArea(child: WeekBoardPage())),
      );
    }
    if (register == UiRegister.kid) return const KidHome();

    final l10n = context.l10n;
    final adult = register == UiRegister.adult;
    final tab = adult ? ref.watch(homeTabProvider) : HomeTab.shopping;
    final section = homeSections[tab]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(section.label(l10n)),
        bottom: section.bottom,
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: l10n.systemTitle,
              icon: const Icon(Icons.developer_mode),
              onPressed: () => context.go(Routes.system),
            ),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: section.body),
            const ActingProfileBar(),
          ],
        ),
      ),
      floatingActionButton: section.fab?.call(context),
      bottomNavigationBar: adult
          ? NavigationBar(
              selectedIndex: tab.index,
              onDestinationSelected: (i) =>
                  ref.read(homeTabProvider.notifier).select(HomeTab.values[i]),
              destinations: [
                for (final t in HomeTab.values)
                  NavigationDestination(
                    icon: Icon(homeSections[t]!.icon),
                    label: homeSections[t]!.label(l10n),
                  ),
              ],
            )
          : null,
    );
  }
}

/// Each destination's section, owned by its feature.
final homeSections = <HomeTab, HomeSection>{
  HomeTab.today: todaySection,
  HomeTab.calendar: calendarSection,
  HomeTab.schedule: scheduleSection,
  HomeTab.tasks: tasksSection,
  HomeTab.meals: mealsSection,
  HomeTab.shopping: shoppingSection,
};
