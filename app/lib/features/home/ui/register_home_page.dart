import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/module_band.dart';
import 'package:wuselwall/core/ui/nav_labels.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/week_board_page.dart';
import 'package:wuselwall/features/calendar/ui/calendar_section.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/kid/ui/kid_home.dart';
import 'package:wuselwall/features/meals/ui/meals_section.dart';
import 'package:wuselwall/features/school/ui/schedule_section.dart';
import 'package:wuselwall/features/settings/application/settings_access.dart';
import 'package:wuselwall/features/settings/ui/open_settings.dart';
import 'package:wuselwall/features/shopping/ui/shopping_section.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/ui/tasks_section.dart';
import 'package:wuselwall/features/today/ui/today_section.dart';
import 'package:wuselwall/features/wusel/ui/ambience_sky.dart';
import 'package:wuselwall/features/wusel/ui/pixel_shift.dart';

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
      return IdleReverter(
        // The board goes back to key appointments (FR-8.11) and to this week when
        // nobody touches it.
        onIdle: () {
          ref.read(boardAllEventsProvider.notifier).set(false);
          ref.read(boardNextWeekProvider.notifier).set(false);
        },
        child: const Scaffold(
          body: SafeArea(child: PixelShift(child: WeekBoardPage())),
        ),
      );
    }
    // `device.pixel_shift` may be on for any device (specs/26); PixelShift does
    // nothing while it is off.
    if (register == UiRegister.kid) return const PixelShift(child: KidHome());

    final l10n = context.l10n;
    final adult = register == UiRegister.adult;
    final tab = adult ? ref.watch(homeTabProvider) : HomeTab.shopping;
    final section = homeSections[tab]!;
    // What waits for the acting guardian, on the Tasks destination (specs/16 step 10.5).
    final approvals = adult ? ref.watch(guardianApprovalsProvider).total : 0;

    final controls = <Widget>[
      if (kDebugMode)
        IconButton(
          tooltip: l10n.systemTitle,
          icon: const Icon(Icons.developer_mode),
          onPressed: () => context.go(Routes.system),
        ),
      // A family tablet with nobody selected has no gear (specs/09).
      if (ref.watch(settingsGearVisibleProvider))
        IconButton(
          tooltip: l10n.settingsTitle,
          icon: const Icon(Icons.settings),
          onPressed: () => unawaited(openSettings(context, ref)),
        ),
    ];
    // Each module has its band (specs/26): the app bar and the selected destination
    // take it, so moving between modules is moving between colours.
    final module = homeTabModule(tab);
    final band = context.ww.band(module);
    // The module's picture stands before the buttons where the bar has room: beside a
    // plain title when the title leaves it, beside a section's own toolbar only on a
    // wide screen. Today's picture is its sky.
    final illustrated =
        tab != HomeTab.today &&
        (section.appBar == null
            ? ModuleIllustration.fits(
                context,
                title: section.label(l10n),
                controls: kMinInteractiveDimension * controls.length,
              )
            : homeBarIsWide(context));
    final actions = [if (illustrated) ModuleIllustration(module), ...controls];
    final base = Theme.of(context);
    final home = Theme(
      data: base.copyWith(
        appBarTheme: base.appBarTheme.copyWith(backgroundColor: band),
        navigationBarTheme: base.navigationBarTheme.copyWith(
          indicatorColor: band,
        ),
      ),
      child: Scaffold(
        appBar:
            section.appBar?.call(context, actions) ??
            AppBar(
              title: tab == HomeTab.today
                  // The Ferien's first and last day hang their ribbon beside the
                  // title, where it never covers it (specs/26).
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(section.label(l10n))),
                        const Flexible(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: Tokens.space3,
                            ),
                            child: FerienRibbon(),
                          ),
                        ),
                      ],
                    )
                  : Text(section.label(l10n)),
              bottom: section.bottom,
              actions: actions,
              // Today's header is the sky of the hour (specs/26 "Ambience").
              flexibleSpace: tab == HomeTab.today
                  ? AmbienceSky(
                      fallback: band,
                      ribbon: false,
                      child: const SizedBox.expand(),
                    )
                  : null,
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
            ? _AdultNavBar(
                tab: tab,
                approvals: approvals,
                onSelect: (t) => ref.read(homeTabProvider.notifier).select(t),
              )
            : null,
      ),
    );
    return PixelShift(child: home);
  }
}

/// The adult home's six destinations (specs/09). The labels keep to one line: their
/// font shrinks until the longest fits, the Stundenplan takes its short label where
/// even that is not enough, and the text scale grows only to 1.3 here.
class _AdultNavBar extends StatelessWidget {
  const _AdultNavBar({
    required this.tab,
    required this.approvals,
    required this.onSelect,
  });

  final HomeTab tab;
  final int approvals;
  final ValueChanged<HomeTab> onSelect;

  String _label(AppLocalizations l10n, HomeTab t, {bool short = false}) {
    if (short && t == HomeTab.schedule) return l10n.scheduleNavLabel;
    return (homeSections[t]!.navLabel ?? homeSections[t]!.label)(l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final base = theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12);
    final full = fitNavLabels(context, [
      for (final t in HomeTab.values) _label(l10n, t),
    ], base: base);
    final short = !full.fits;
    final style = short
        ? fitNavLabels(
            context,
            [for (final t in HomeTab.values) _label(l10n, t, short: true)],
            base: base,
            // A very small phone: smaller still rather than a broken word.
            minSize: 9,
          ).style
        : full.style;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Theme(
        data: theme.copyWith(
          navigationBarTheme: theme.navigationBarTheme.copyWith(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) =>
                  (theme.navigationBarTheme.labelTextStyle?.resolve(states) ??
                          base)
                      .copyWith(fontSize: style.fontSize),
            ),
          ),
        ),
        // The floor: at a very large text scale a label shortens with "…" rather
        // than break inside its word.
        child: DefaultTextStyle.merge(
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (i) => onSelect(HomeTab.values[i]),
            // Six destinations do not fit a phone with their labels: there only
            // the selected one is labelled, the others keep their tooltip.
            labelBehavior: MediaQuery.sizeOf(context).width < 600
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : null,
            destinations: [
              for (final t in HomeTab.values)
                NavigationDestination(
                  icon: Badge.count(
                    count: approvals,
                    isLabelVisible: t == HomeTab.tasks && approvals > 0,
                    child: Icon(homeSections[t]!.icon),
                  ),
                  label: unbreakable(_label(l10n, t, short: short)),
                  tooltip: homeSections[t]!.label(l10n),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colour of each destination (specs/26 "Module bands").
AppModule homeTabModule(HomeTab tab) => switch (tab) {
  HomeTab.today => AppModule.today,
  HomeTab.calendar => AppModule.calendar,
  HomeTab.schedule => AppModule.schedule,
  HomeTab.tasks => AppModule.tasks,
  HomeTab.meals => AppModule.meals,
  HomeTab.shopping => AppModule.shopping,
};

/// Each destination's section, owned by its feature.
final homeSections = <HomeTab, HomeSection>{
  HomeTab.today: todaySection,
  HomeTab.calendar: calendarSection,
  HomeTab.schedule: scheduleSection,
  HomeTab.tasks: tasksSection,
  HomeTab.meals: mealsSection,
  HomeTab.shopping: shoppingSection,
};
