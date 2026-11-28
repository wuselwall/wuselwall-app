import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/system_bars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/last_updated.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/kid/application/child_view.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_home.dart';
import 'package:wuselwall/features/kid/ui/kid_new_badge.dart';
import 'package:wuselwall/features/kid/ui/kid_points_page.dart';
import 'package:wuselwall/features/kid/ui/kid_today_page.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/rituals/ui/meal_wish_widgets.dart';
import 'package:wuselwall/features/rituals/ui/table_question_widgets.dart';
import 'package:wuselwall/features/rituals/ui/week_review_widgets.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';
import 'package:wuselwall/features/settings/application/settings_access.dart';
import 'package:wuselwall/features/settings/ui/open_settings.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// What the simple view has open: the child's days, or one of the three things a card
/// leads to. They open inside the home, not as routes, so the wall's idle timer and the
/// avatar bar stay with them.
enum _Open { days, lessons, points, shopping }

/// The simple view (specs/09 "The simple view"): what a child under twelve gets on every
/// device. One page without tabs, and nothing about anyone else: the child's chores,
/// school, appointments and the meal, for today and, where the family leaves the
/// calendar on for children, the next three days. No other day can be reached.
class KidSimpleHome extends ConsumerStatefulWidget {
  const KidSimpleHome({required this.member, this.onWall = false, super.key});

  final Member member;

  /// On the wall display: a way back to the week board stands in the band.
  final bool onWall;

  @override
  ConsumerState<KidSimpleHome> createState() => _KidSimpleHomeState();
}

class _KidSimpleHomeState extends ConsumerState<KidSimpleHome> {
  /// Anchors the coin's flight and keeps the pill's state (its count) across rebuilds.
  final _balanceKey = GlobalKey();
  final _cheers = ValueNotifier<int>(0);
  final _heldBalance = ValueNotifier<int?>(null);

  _Open _open = _Open.days;

  /// The day in view, counted from today.
  int _day = 0;

  @override
  void dispose() {
    _cheers.dispose();
    _heldBalance.dispose();
    super.dispose();
  }

  void _show(_Open open) => setState(() => _open = open);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    final today = ref.watch(kidTodayProvider);
    final days = ref.watch(childDaysProvider) ?? [today];
    final shopping = ref.watch(shoppingOfferedProvider);
    // The day chosen yesterday is gone, and so is a page a guardian has switched off.
    final index = _day < days.length ? _day : 0;
    final open = _open == _Open.shopping && !shopping ? _Open.days : _open;
    kidListenForApprovals(ref, member.id);

    final (module, decor) = switch (open) {
      _Open.days => (AppModule.today, Decor.sun),
      _Open.lessons => (AppModule.schedule, Decor.lilac),
      _Open.points => (AppModule.tasks, Decor.coral),
      _Open.shopping => (AppModule.shopping, Decor.mint),
    };
    final band = context.ww.band(module);
    final body = switch (open) {
      _Open.days => _Days(
        member: member,
        days: days,
        selected: index,
        onDay: (i) => setState(() => _day = i),
        balanceKey: _balanceKey,
        cheers: _cheers,
        heldBalance: _heldBalance,
        onPoints: () => _show(_Open.points),
        onLessons: () => _show(_Open.lessons),
        onShopping: shopping ? () => _show(_Open.shopping) : null,
      ),
      _Open.lessons => _Lessons(actor: member.id, day: days[index]),
      _Open.points => KidPointsPage(
        key: ValueKey('points-${member.id}'),
        actor: member.id,
      ),
      _Open.shopping => const ShoppingBody(),
    };

    return KidChrome(
      // The device's back button closes what a card opened, before it leaves the app.
      child: PopScope(
        canPop: open == _Open.days,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _show(_Open.days);
        },
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The band of what is open (specs/26), up under the status bar. It holds
              // the one way back and, for the grown-ups, the quiet gear.
              ColoredBox(
                color: band,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space2,
                      vertical: Tokens.space1,
                    ),
                    child: Row(
                      children: [
                        if (open != _Open.days)
                          _BandButton(
                            key: const ValueKey('kid-simple-back'),
                            icon: Icons.arrow_back_rounded,
                            label: l10n.kidSimpleBack,
                            onTap: () => _show(_Open.days),
                          )
                        else if (widget.onWall)
                          _BandButton(
                            key: const ValueKey('kid-simple-week'),
                            icon: Icons.arrow_back_rounded,
                            label: l10n.boardBackToWeek,
                            onTap: () {
                              guardianStepDown(ref);
                              ref.read(actingProfileProvider.notifier).clear();
                            },
                          ),
                        const Spacer(),
                        if (ref.watch(settingsGearVisibleProvider))
                          IconButton(
                            tooltip: l10n.settingsTitle,
                            icon: const Icon(Icons.settings_outlined),
                            // ink2: ink3 is not used on a band (specs/26).
                            color: context.ww.ink2,
                            onPressed: () =>
                                unawaited(openSettings(context, ref)),
                          )
                        else
                          const SizedBox.square(
                            dimension: kMinInteractiveDimension,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const StaleStrip(),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: KidDecorScope(
                    decor: decor,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: KidHome.maxContentWidth,
                        ),
                        child: body,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Who is here: on a shared device the avatars, where the child hands the
          // device on. A child's own phone has none.
          bottomNavigationBar: SystemBars(
            navigationColor: Theme.of(context).colorScheme.surfaceContainer,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: const ActingProfileBar(),
            ),
          ),
        ),
      ),
    );
  }
}

/// A way back in the band: an arrow and a word, as large as a kid's touch target.
class _BandButton extends StatelessWidget {
  const _BandButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 28),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      minimumSize: const Size(56, 56),
      textStyle: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

/// The child's days: Wusel's greeting, the day chips and the chosen day.
class _Days extends ConsumerWidget {
  const _Days({
    required this.member,
    required this.days,
    required this.selected,
    required this.onDay,
    required this.balanceKey,
    required this.cheers,
    required this.heldBalance,
    required this.onPoints,
    required this.onLessons,
    required this.onShopping,
  });

  final Member member;
  final List<DateTime> days;
  final int selected;
  final ValueChanged<int> onDay;
  final GlobalKey balanceKey;
  final ValueNotifier<int> cheers;
  final ValueNotifier<int?> heldBalance;
  final VoidCallback onPoints;
  final VoidCallback onLessons;
  final VoidCallback? onShopping;

  /// Narrower than this, the four day buttons take two rows.
  static const _twoRowsBelow = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.ww.member(member.color);
    final balance = ref.watch(pointBalancesProvider).value;
    final points = kidBalanceOf(balance ?? const {}, member.id);
    final day = days[selected];
    final isToday = selected == 0;

    return ListView(
      key: const ValueKey('kid-simple-days'),
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space4,
        Tokens.space4,
        Tokens.space8,
      ),
      children: [
        KidGreeting(
          member: member,
          tint: colors.tint,
          ink: colors.ink,
          onInk: colors.onInk,
          // The stars lead to what they buy: the simple view has no tab for them.
          balance: Semantics(
            button: true,
            label: l10n.kidYourPoints,
            child: InkWell(
              key: const ValueKey('kid-simple-points'),
              customBorder: const StadiumBorder(),
              onTap: onPoints,
              child: ValueListenableBuilder<int?>(
                valueListenable: heldBalance,
                builder: (context, held, _) => KidBalancePill(
                  key: balanceKey,
                  balance: held ?? points,
                  loaded: balance != null,
                ),
              ),
            ),
          ),
          cheers: cheers,
        ),
        // A new badge is Wusel's line in the greeting; without a lively Wusel it takes
        // a slim line of its own.
        if (ref.watch(lighterDayProvider).wusel != WuselPresence.lively)
          KidNewBadge(actor: member.id, withWusel: false),
        // The two moments of the family's rituals, each only at its time (specs/27).
        if (isToday) ...[
          const WeekReviewCard(kid: true),
          const TableQuestionCard(kid: true),
        ],
        if (days.length > 1) ...[
          const SizedBox(height: Tokens.space4),
          // One row on a tablet; on a phone two rows of two, so every word keeps
          // the same size ("Tomorrow" and "Wednesday" do not fit a quarter of 360 dp).
          LayoutBuilder(
            builder: (context, box) {
              final perRow = box.maxWidth < _twoRowsBelow ? 2 : days.length;
              Widget chip(int i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space1),
                  child: _DayChip(
                    key: ValueKey('kid-simple-day-$i'),
                    date: days[i],
                    offset: i,
                    selected: i == selected,
                    onTap: () => onDay(i),
                  ),
                ),
              );
              return Column(
                children: [
                  for (var row = 0; row < days.length; row += perRow)
                    Row(
                      children: [
                        for (
                          var i = row;
                          i < row + perRow && i < days.length;
                          i++
                        )
                          chip(i),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
        if (isToday) ...[
          KidSectionTitle(l10n.kidTasksTitle),
          KidTasksSection(
            actor: member.id,
            balanceKey: balanceKey,
            cheers: cheers,
            heldBalance: heldBalance,
            balance: points,
          ),
        ],
        const SizedBox(height: Tokens.space4),
        _School(
          actor: member.id,
          day: day,
          isToday: isToday,
          range: (days.first, kidTomorrowOf(days.last)),
          onLessons: onLessons,
        ),
        KidEventsSection(
          actor: member.id,
          day: day,
          title: isToday ? null : l10n.kidSimpleAppointments,
        ),
        const SizedBox(height: Tokens.space4),
        KidMealCard(day: day),
        if (isToday) KidWishCard(member: member),
        if (!isToday)
          _NothingPlanned(
            actor: member.id,
            day: day,
            range: (days.first, kidTomorrowOf(days.last)),
          ),
        if (onShopping != null) ...[
          const SizedBox(height: Tokens.space6),
          Semantics(
            button: true,
            label: l10n.kidTabShopping,
            excludeSemantics: true,
            child: KidCard(
              key: const ValueKey('kid-simple-shopping'),
              onTap: onShopping,
              child: Row(
                children: [
                  const Icon(Icons.shopping_basket_rounded, size: 40),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Text(
                      l10n.kidTabShopping,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 32),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One of the four days: "Heute", "Morgen", then the weekday. The weekday is what a
/// child knows; the date is only spoken.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.offset,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final DateTime date;

  /// Days from today: 0 is today.
  final int offset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final word = switch (offset) {
      0 => l10n.kidTodayMarker,
      1 => l10n.kidSimpleTomorrow,
      _ => context.weekdayLong(date),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$word, ${context.fullDate(date)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : context.ww.line,
            width: selected ? 3 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 72,
            // Four chips share a phone's width: a long weekday shrinks to fit rather
            // than run past the chip's border.
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  word,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.onPrimaryContainer : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// School on [day] as one card: the hours, on today the lesson running now, and the
/// changes. A tap shows the day's lessons. Under it what to pack: on today what
/// tomorrow needs, on another day what that day needs. A child without a timetable
/// has no card at all.
class _School extends ConsumerWidget {
  const _School({
    required this.actor,
    required this.day,
    required this.isToday,
    required this.range,
    required this.onLessons,
  });

  final String actor;
  final DateTime day;
  final bool isToday;

  /// The days asked for in one call: the child's days and the one after.
  final (DateTime, DateTime) range;
  final VoidCallback onLessons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final w = ref.watch(schoolWeekProvider(range)).value;
    // While it loads there is no card; a failure shows on the chores above already.
    if (w == null || w.timetableOf(actor) == null) {
      return const SizedBox.shrink();
    }
    final school = w.dayOf(actor, day);
    final summary = kidSchoolSummary(
      school,
      isToday ? ref.watch(kidMinutesProvider) : -1,
    );
    final needs = isToday
        ? w.dayOf(actor, kidTomorrowOf(day))?.equipment ?? const <String>[]
        : school?.equipment ?? const <String>[];
    final lines = summary == null
        ? [
            school?.holidayName != null
                ? l10n.kidHoliday(school!.holidayName!)
                : isToday
                ? l10n.kidNoSchoolToday
                : l10n.kidSimpleNoSchool,
          ]
        : [
            '${context.time(summary.starts)} – '
                '${context.time(summary.ends)}',
            if (summary.now case final subject?)
              l10n.kidSchoolNowSubject(subject),
            if (summary.changes > 0) l10n.kidSchoolChanges(summary.changes),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: summary != null,
          label: [l10n.scheduleNavLabel, ...lines].join(', '),
          excludeSemantics: true,
          child: KidCard(
            key: const ValueKey('kid-simple-school'),
            onTap: summary == null ? null : onLessons,
            child: Row(
              children: [
                const Icon(Icons.school_rounded, size: 40),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary != null)
                        Text(
                          l10n.scheduleNavLabel,
                          style: theme.textTheme.bodyLarge,
                        ),
                      Text(
                        lines.first,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: summary == null
                              ? null
                              : Tokens.fontNumeric,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      for (final line in lines.skip(1))
                        Text(line, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
                if (summary != null)
                  const Icon(Icons.chevron_right_rounded, size: 32),
              ],
            ),
          ),
        ),
        if (needs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space3),
            child: KidCard(
              color: context.ww.paper(
                PaperTints.tints.firstWhere((t) => t.key == 'lemon'),
              ),
              child: Row(
                children: [
                  const Icon(Icons.backpack_rounded, size: 32),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Text(
                      isToday
                          ? l10n.kidTomorrowNeeds(needs.join(', '))
                          : l10n.kidSimpleNeeds(needs.join(', ')),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A day ahead with nothing on it says so, instead of an empty page under the chips:
/// no school card, no appointment and no meal. Nothing while any of them still loads.
class _NothingPlanned extends ConsumerWidget {
  const _NothingPlanned({
    required this.actor,
    required this.day,
    required this.range,
  });

  final String actor;
  final DateTime day;
  final (DateTime, DateTime) range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolWeekProvider(range));
    final window = ref.watch(occurrencesProvider((from: day, to: day)));
    if (!school.hasValue || !window.hasValue) return const SizedBox.shrink();
    final nothing =
        school.requireValue.timetableOf(actor) == null &&
        kidEventsFor(window.requireValue.occurrences, actor, day).isEmpty &&
        ref.watch(kidMealsProvider(day)).isEmpty;
    if (!nothing) return const SizedBox.shrink();
    return KidCard(
      key: const ValueKey('kid-simple-nothing'),
      child: Text(
        context.l10n.kidSimpleNothing,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// The lessons of [day], one card each, as on the older children's timetable tab.
class _Lessons extends ConsumerWidget {
  const _Lessons({required this.actor, required this.day});

  final String actor;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(kidTodayProvider);
    final week = ref.watch(schoolWeekProvider((day, day)));
    final data = ref.watch(schoolDataProvider).value;
    return ListView(
      key: const ValueKey('kid-simple-lessons'),
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space3),
          child: Text(
            context.weekdayLong(day),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        switch (week) {
          AsyncData<SchoolWeek>(:final value) => KidDayLessons(
            day: value.dayOf(actor, day),
            iconOf: (subject) => schoolIcon(data?.iconKeyFor(subject)),
            minutesNow: day == today ? ref.watch(kidMinutesProvider) : null,
          ),
          AsyncError() => const SizedBox.shrink(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}
