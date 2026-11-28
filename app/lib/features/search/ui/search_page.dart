import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/error_mapper.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/search.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/search_field.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/settings/application/settings_access.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/ui/settings_search.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_editor.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/tasks/ui/tasks_rewards_tab.dart';

/// What a search looks through.
enum SearchScope {
  /// Appointments, tasks and rewards, recipes, shopping items and settings (FR-10.3).
  all,

  /// Appointments only: how the search opens from the calendar (FR-10.2).
  events,
}

/// The kinds of things the search finds, in the order of the home's tabs; settings,
/// which have no tab, come last.
enum SearchKind { events, tasks, recipes, shopping, settings }

/// A section shows this many rows until "Show all" is tapped: five kinds share a screen.
const searchSectionRows = 5;

/// The server is asked this long after the last keystroke, not on each one.
const searchDebounce = Duration(milliseconds: 350);

/// The search of the adult home (FR-10.2, FR-10.3): one field, and under it what answers
/// it, grouped by kind. Tasks, recipes, shopping items and settings are what the app
/// already holds and answer as the person types; appointments are asked of the server
/// (`search`), which knows more than the weeks in view. A server without that function
/// leaves the appointments out and the rest works the same.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({this.scope = SearchScope.all, super.key});

  final SearchScope scope;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  /// As typed: what the app holds itself is searched at once.
  String _query = '';

  /// What the server was last asked: [_query] once it has rested for [searchDebounce].
  String _asked = '';
  Timer? _debounce;
  final _expanded = <SearchKind>{};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    setState(() {
      _query = text;
      _expanded.clear();
    });
    final ask = text.trim();
    if (ask == _asked) return;
    _debounce = Timer(searchDebounce, () {
      if (mounted) setState(() => _asked = ask);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final eventsOnly = widget.scope == SearchScope.events;
    final withEvents = ref.watch(eventSearchSupportedProvider);
    final terms = searchTerms(_query);
    return Scaffold(
      appBar: AppBar(
        // Opened by its address alone (a link, a reload on the web) the search has
        // no page under it: Back then leads home.
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: Text(eventsOnly ? l10n.searchEventsTitle : l10n.searchTitle),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space4,
                Tokens.space4,
                Tokens.space2,
              ),
              child: SearchField(
                key: const ValueKey('search-field'),
                hint: eventsOnly ? l10n.searchEventsHint : l10n.searchHint,
                autofocus: true,
                onChanged: _changed,
              ),
            ),
            Expanded(
              child: terms.isEmpty
                  ? _Intro(
                      text: eventsOnly
                          ? l10n.searchEventsIntro
                          : withEvents
                          ? l10n.searchIntro
                          : l10n.searchIntroLocal,
                    )
                  : _results(context, terms, withEvents: withEvents),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(
    BuildContext context,
    List<String> terms, {
    required bool withEvents,
  }) {
    final l10n = context.l10n;
    final local = widget.scope == SearchScope.all;

    // Appointments: only for a query the server takes, and only once it has rested.
    final askable = withEvents && _asked.length >= 2 && _asked == _query.trim();
    final waiting = withEvents && _query.trim().length >= 2 && !askable;
    final events = askable ? ref.watch(eventSearchProvider(_asked)) : null;
    final found = events?.value;

    final sections = <Widget>[
      if (waiting || (events != null && events.isLoading && found == null))
        _Section(
          kind: SearchKind.events,
          title: l10n.searchSectionEvents,
          children: const [LinearProgressIndicator()],
        )
      else if (events != null && events.hasError && found == null)
        _Section(
          kind: SearchKind.events,
          title: l10n.searchSectionEvents,
          children: [
            ListTile(
              key: const ValueKey('search-events-failed'),
              leading: const Icon(Icons.error_outline),
              title: Text(mapError(events.error!).message(l10n)),
              trailing: TextButton(
                onPressed: () => ref.invalidate(eventSearchProvider(_asked)),
                child: Text(l10n.retry),
              ),
            ),
          ],
        )
      else if (found != null) ...[
        if (found.upcoming.isNotEmpty)
          _section(
            SearchKind.events,
            l10n.searchSectionEvents,
            [for (final o in found.upcoming) _EventTile(occurrence: o)],
            // From the calendar the appointments are all there is to show.
            whole: !local,
          ),
        if (found.past.isNotEmpty)
          _Section(
            kind: SearchKind.events,
            title: l10n.searchSectionPast,
            past: true,
            children: [
              for (final o
                  in local && found.upcoming.isNotEmpty
                      ? found.past.take(searchSectionRows)
                      : found.past)
                _EventTile(occurrence: o),
            ],
          ),
        if (found.more && !found.isEmpty)
          Padding(
            key: const ValueKey('search-more'),
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space4,
              vertical: Tokens.space2,
            ),
            child: Text(
              l10n.searchMore,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
      if (local) ..._localSections(context, terms),
    ];

    if (sections.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          key: const ValueKey('search-empty'),
          padding: const EdgeInsets.all(Tokens.space6),
          child: Text(l10n.searchNothingFound, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      key: const ValueKey('search-results'),
      padding: const EdgeInsets.only(bottom: Tokens.space6),
      children: sections,
    );
  }

  /// What the app holds itself. A list that has not loaded, or failed to, finds nothing:
  /// its own tab says why.
  List<Widget> _localSections(BuildContext context, List<String> terms) {
    final l10n = context.l10n;
    final query = _query;

    final chores = searchIn(
      query,
      ref.watch(taskDefinitionsProvider).value ?? const <TaskDefinition>[],
      (d) => [d.title],
    );
    final rewards = searchIn(
      query,
      ref.watch(rewardsProvider).value ?? const <Reward>[],
      (r) => [r.title],
    );
    final recipes = searchIn(
      query,
      ref.watch(recipesProvider).value ?? const <Recipe>[],
      (r) => [r.title, ...r.tags],
    );
    final lists = {
      for (final list
          in ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[])
        list.id: list,
    };
    final items = searchIn(query, [
      for (final item
          in ref.watch(shoppingItemsProvider).value ?? const <ShoppingItem>[])
        if (!item.checked) item,
    ], (i) => [i.name]);
    final settings = ref.watch(settingsAccessProvider) == SettingsAccess.full
        ? searchSettings(
            l10n,
            settingsSearchIndex(l10n, ref.watch(settingsEnvProvider)),
            query,
          )
        : const <SettingsHit>[];

    return [
      if (chores.isNotEmpty || rewards.isNotEmpty)
        _section(SearchKind.tasks, l10n.searchSectionTasks, [
          for (final d in chores) _ChoreTile(definition: d),
          for (final r in rewards) _RewardTile(reward: r),
        ]),
      if (recipes.isNotEmpty)
        _section(SearchKind.recipes, l10n.mealsRecipesTitle, [
          for (final r in recipes) _RecipeTile(recipe: r),
        ]),
      if (items.isNotEmpty)
        _section(SearchKind.shopping, l10n.shoppingTitle, [
          for (final i in items) _ItemTile(item: i, list: lists[i.listId]),
        ]),
      if (settings.isNotEmpty)
        _section(SearchKind.settings, l10n.settingsTitle, [
          for (final hit in settings) SettingsHitTile(hit: hit),
        ]),
    ];
  }

  /// A section of [rows], cut at [searchSectionRows] with a way to see the rest unless
  /// it is shown [whole].
  Widget _section(
    SearchKind kind,
    String title,
    List<Widget> rows, {
    bool whole = false,
  }) {
    final all = whole || _expanded.contains(kind);
    final cut = !all && rows.length > searchSectionRows;
    return _Section(
      kind: kind,
      title: title,
      children: [
        ...cut ? rows.take(searchSectionRows) : rows,
        if (cut)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
              child: TextButton(
                key: ValueKey('search-all-${kind.name}'),
                onPressed: () => setState(() => _expanded.add(kind)),
                child: Text(l10n.searchShowAll(rows.length)),
              ),
            ),
          ),
      ],
    );
  }

  AppLocalizations get l10n => context.l10n;
}

/// What the search is for, while nothing is typed.
class _Intro extends StatelessWidget {
  const _Intro({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      key: const ValueKey('search-intro'),
      padding: const EdgeInsets.all(Tokens.space6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.kind,
    required this.title,
    required this.children,
    this.past = false,
  });

  final SearchKind kind;
  final String title;
  final List<Widget> children;
  final bool past;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('search-section-${kind.name}${past ? '-past' : ''}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space4,
          Tokens.space4,
          Tokens.space1,
        ),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      ),
      ...children,
    ],
  );
}

/// Leaves the search for the home tab [tab]. The search lies above the home it was opened
/// from; opened by its address alone, it leads there.
void _showTab(BuildContext context, WidgetRef ref, HomeTab tab) {
  ref.read(homeTabProvider.notifier).select(tab);
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home);
  }
}

/// One appointment: what, when and where. A tap shows its day in the calendar, where it
/// stands among the day's other appointments and opens as it always does.
class _EventTile extends ConsumerWidget {
  const _EventTile({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final o = occurrence;
    final from = o.localStartDate;
    final to = o.localEndDate;
    String day(DateTime d) =>
        '${context.weekdayShort(d)} ${context.mediumDate(d)}';
    final starts = o.localStarts;
    final ends = o.localEnds;
    final when = [
      if (to.isAfter(from)) '${day(from)} – ${day(to)}' else day(from),
      if (!o.allDay && starts != null && ends != null)
        '${context.time(starts)}–${context.time(ends)}',
      if (o.location case final place? when place.trim().isNotEmpty) place,
    ].join(' · ');
    return ListTile(
      key: ValueKey('search-event-${o.id}'),
      leading: SearchLeading(
        child: Icon(
          o.isRecurring ? Icons.event_repeat_outlined : Icons.event_outlined,
          semanticLabel: o.isRecurring ? l10n.searchEventRepeats : null,
        ),
      ),
      title: Text(o.title),
      subtitle: Text(when),
      onTap: () {
        // An appointment that began earlier and still runs is shown on today.
        final today = dateOnly(ref.read(nowProvider));
        final running = from.isBefore(today) && !to.isBefore(today);
        ref.read(calendarViewProvider.notifier).openDay(running ? today : from);
        _showTab(context, ref, HomeTab.calendar);
      },
    );
  }
}

class _ChoreTile extends ConsumerWidget {
  const _ChoreTile({required this.definition});

  final TaskDefinition definition;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: ValueKey('search-chore-${definition.id}'),
    leading: SearchLeading(child: TaskGlyph(iconKey: definition.iconKey)),
    title: Text(definition.title),
    subtitle: Text(context.l10n.searchKindChore),
    onTap: () async {
      final members = ref.read(membersProvider).value ?? const <Member>[];
      final defaults = await ref.read(taskDefaultsProvider.future);
      if (!context.mounted) return;
      await showTaskEditor(
        context,
        members: members,
        defaults: defaults,
        existing: definition,
      );
    },
  );
}

class _RewardTile extends ConsumerWidget {
  const _RewardTile({required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: ValueKey('search-reward-${reward.id}'),
    leading: const SearchLeading(child: Icon(Icons.card_giftcard_outlined)),
    title: Text(reward.title),
    subtitle: Text(context.l10n.searchKindReward),
    onTap: () => openRewardEditor(context, ref, existing: reward),
  );
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('search-recipe-${recipe.id}'),
    leading: const SearchLeading(child: Icon(Icons.menu_book)),
    title: Text(recipe.title),
    subtitle: recipe.tags.isEmpty ? null : Text(recipe.tags.join(', ')),
    onTap: () => context.push(Routes.recipeView, extra: recipe),
  );
}

/// An open item of a shopping list. A tap shows the list it is on.
class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.list});

  final ShoppingItem item;
  final ShoppingList? list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = item.quantity;
    return ListTile(
      key: ValueKey('search-item-${item.id}'),
      leading: const SearchLeading(child: Icon(Icons.shopping_basket_outlined)),
      title: Text(
        quantity == null || quantity.trim().isEmpty
            ? item.name
            : '${item.name} · $quantity',
      ),
      subtitle: list == null ? null : Text(list!.name),
      onTap: () {
        if (item.listId case final id?) {
          ref.read(selectedListIdProvider.notifier).select(id);
        }
        _showTab(context, ref, HomeTab.shopping);
      },
    );
  }
}
