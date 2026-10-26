import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return _KidChrome(
      child: Scaffold(
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
                child: KidDecorScope(
                  decor: _decor(tab),
                  // A wide tablet or screen keeps the cards at a readable width:
                  // a tick far from its title is hard to connect.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: maxContentWidth,
                      ),
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The bars are the frame of every page: their text grows with the system
        // setting only so far, so a large font cannot push them over the page.
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    navigationBarTheme: NavigationBarThemeData(
                      indicatorColor: band,
                      // On a phone the five labels share 360 dp: the font shrinks
                      // until the longest fits, so "Stundenplan" stays one word.
                      labelTextStyle: WidgetStatePropertyAll(
                        _labelStyle(context, [
                          for (final t in KidTab.values) _label(l10n, t),
                        ]),
                      ),
                      iconTheme: const WidgetStatePropertyAll(
                        IconThemeData(size: 32),
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: tab.index,
                    onDestinationSelected: (i) => ref
                        .read(kidTabProvider.notifier)
                        .select(KidTab.values[i]),
                    destinations: [
                      for (final t in KidTab.values)
                        NavigationDestination(
                          icon: Icon(_icon(t)),
                          label: _label(l10n, t),
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
        ),
      ),
    );
  }

  /// The widest a kid page's content gets (specs/09: tablets in landscape).
  static const maxContentWidth = 840.0;

  static String _label(AppLocalizations l10n, KidTab tab) => switch (tab) {
    KidTab.today => l10n.kidTabToday,
    KidTab.school => l10n.kidTabSchool,
    KidTab.points => l10n.kidTabPoints,
    KidTab.shopping => l10n.kidTabShopping,
    KidTab.family => l10n.kidTabFamily,
  };

  /// 16 px bold, or smaller until the longest of [labels] fits its fifth of the
  /// width (never below 11 px).
  static TextStyle _labelStyle(BuildContext context, List<String> labels) {
    const base = TextStyle(
      fontFamily: Tokens.fontUi,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final slot = MediaQuery.sizeOf(context).width / labels.length - 12;
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: base),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    if (widest <= slot) return base;
    return base.copyWith(fontSize: (16 * slot / widest).clamp(11.0, 16.0));
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

/// What the kid home does around its pages: on a phone it stays upright (decided
/// 2026-10-26: held sideways the bars left no room for the page), and a page's
/// message, such as a tick's "Rückgängig", goes when the child switches tab or
/// person, so nobody undoes someone else's chore.
class _KidChrome extends ConsumerStatefulWidget {
  const _KidChrome({required this.child});

  final Widget child;

  @override
  ConsumerState<_KidChrome> createState() => _KidChromeState();
}

class _KidChromeState extends ConsumerState<_KidChrome> {
  bool? _phone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final phone = MediaQuery.sizeOf(context).shortestSide < 600;
    if (phone == _phone) return;
    _phone = phone;
    unawaited(
      SystemChrome.setPreferredOrientations(
        phone ? const [DeviceOrientation.portraitUp] : const [],
      ),
    );
  }

  @override
  void dispose() {
    // Other registers and screens turn freely again.
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void clear() => ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    ref
      ..listen(kidTabProvider, (_, _) => clear())
      ..listen(actingProfileProvider, (_, _) => clear());
    return widget.child;
  }
}
