import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/region/application/region_providers.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';
import 'package:wuselwall/features/region/ui/region_field.dart';
import 'package:wuselwall/features/region/ui/region_picker_page.dart';
import 'package:wuselwall/features/region/ui/region_text.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

import '../support/fake_region.dart';
import '../support/fake_school.dart';
import '../support/fakes.dart';

final de = lookupAppLocalizations(const Locale('de'));

class _DelayedRegionRepository extends FakeRegionRepository {
  _DelayedRegionRepository()
    : super(
        status: FeedStatus(country: 'CH', fetchedAt: DateTime.now()),
      );

  final ready = Completer<void>();

  @override
  Future<Result<List<Region>>> regions(String country) async {
    await ready.future;
    return super.regions(country);
  }
}

/// Records the settings the school form and the settings page write.
class FakeSettings implements HouseholdSettingsRepository {
  FakeSettings({this.householdRegion});

  final String? householdRegion;
  final sets = <({String key, Object? value})>[];

  List<SettingEntry> get rows => [
    for (final e in demoSettingCatalogue())
      if (e.key == 'household.region' && householdRegion != null)
        SettingEntry(
          key: e.key,
          scope: e.scope,
          type: e.type,
          constraints: e.constraints,
          selfService: e.selfService,
          defaultValue: null,
          value: householdRegion,
          isDefault: false,
        )
      else
        e,
  ];

  @override
  Future<Result<List<SettingEntry>>> all() async => Ok(rows);

  @override
  Future<Result<void>> set({
    required String? actor,
    required String key,
    required Object? value,
    String? profileId,
    String? deviceId,
  }) async {
    sets.add((key: key, value: value));
    return const Ok(null);
  }

  @override
  Future<Result<void>> reset({
    required String? actor,
    required String key,
    String? profileId,
    String? deviceId,
  }) async => const Ok(null);
}

/// What the picker returned: [done] once it is closed, [pick] null when it was dismissed.
class PickerProbe {
  RegionPick? pick;
  bool done = false;
}

/// Opens the picker over the current page.
Future<PickerProbe> openPicker(WidgetTester t, {String? current}) async {
  final probe = PickerProbe();
  unawaited(
    showRegionPicker(
      t.element(find.byType(Scaffold).first),
      current: current,
    ).then((pick) {
      probe
        ..pick = pick
        ..done = true;
    }),
  );
  await t.pumpAndSettle();
  return probe;
}

Finder inPicker(Finder f) =>
    find.descendant(of: find.byType(RegionPickerPage), matching: f);

Future<void> openSchedule(WidgetTester t) async {
  await t.tap(find.text('Stundenplan'));
  await t.pumpAndSettle();
}

void main() {
  group('region models', () {
    test('a name falls back to German, then to any name', () {
      final fr = Region.fromJson({
        'code': 'AT-9',
        'country': 'AT',
        'parent_code': null,
        'level': 1,
        'category': 'Bundesland',
        'short_name': 'W',
        'names': {'fr': 'Vienne'},
      });
      expect(fr.displayName('en'), 'Vienne');
      final canton = referenceRegions().firstWhere((r) => r.code == 'CH-ZH');
      expect(canton.displayName('fr'), 'Zürich');
      expect(canton.displayName('en'), 'Zurich');
    });

    test('a cache is stale when missing or older than seven days', () {
      final now = DateTime(2026, 10, 14);
      expect(FeedStatus(country: 'CH').isStale(now), isTrue);
      expect(
        FeedStatus(
          country: 'CH',
          fetchedAt: now.subtract(const Duration(days: 8)),
        ).isStale(now),
        isTrue,
      );
      expect(
        FeedStatus(
          country: 'CH',
          fetchedAt: now.subtract(const Duration(days: 1)),
        ).isStale(now),
        isFalse,
      );
    });

    test('the index finds the canton above and the regions below', () {
      final index = RegionIndex(referenceRegions());
      expect(index.top('CH-ZH-UE-0003')?.code, 'CH-ZH');
      expect(
        index.below('CH-ZH').map((r) => r.code),
        unorderedEquals(['CH-ZH-UE', 'CH-ZH-UE-0003', 'CH-ZH-UE-0004']),
      );
      expect(index.below('CH-BE'), isEmpty);
      expect(index.parentOf(index['CH-ZH-UE-0003']!)?.code, 'CH-ZH-UE');
    });

    test('a label names a municipality with its canton', () {
      final index = RegionIndex(referenceRegions());
      expect(
        regionLabel(de, index, 'CH-ZH-UE-0003', 'de'),
        'Uster (Gemeinde), Kanton Zürich (ZH)',
      );
      expect(regionLabel(de, index, 'CH-ZH', 'de'), 'Kanton Zürich (ZH)');
      expect(regionLabel(de, index, 'CH-XX-1', 'de'), 'CH-XX-1');
    });

    test(
      'an in-flight region lookup survives losing its last listener',
      () async {
        final repository = _DelayedRegionRepository();
        final container = ProviderContainer.test(
          overrides: [regionRepositoryProvider.overrideWithValue(repository)],
        );
        final provider = countryRegionsProvider('CH');
        final subscription = container.listen(provider, (_, _) {});
        final pending = container.read(provider.future);
        subscription.close();
        await container.pump();
        final next = container.listen(provider, (_, _) {});
        repository.ready.complete();
        expect(await container.read(provider.future), isNotEmpty);
        expect(await pending, isNotEmpty);
        expect(repository.statusReads, ['CH']);
        expect(repository.regionReads, ['CH']);
        next.close();
      },
    );

    test('failed region lookups are discarded when the field leaves', () async {
      // An empty cache: only then is a failed refresh the lookup's error.
      final repository = FakeRegionRepository(
        regions: const [],
        refreshFailure: const NetworkFailure(),
      );
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [regionRepositoryProvider.overrideWithValue(repository)],
      );
      final provider = countryRegionsProvider('CH');
      for (var i = 0; i < 2; i++) {
        final subscription = container.listen(provider, (_, _) {});
        await expectLater(
          container.read(provider.future),
          throwsA(isA<NetworkFailure>()),
        );
        subscription.close();
        await container.pump();
      }
      expect(repository.refreshes, ['CH', 'CH']);
    });

    test('a refresh runs only when the cache is missing or stale', () async {
      final now = DateTime(2026, 10, 14);
      final missing = FakeRegionRepository();
      await refreshCountryIfStale(missing, 'CH', now: now);
      expect(missing.refreshes, ['CH']);

      final fresh = FakeRegionRepository(
        status: FeedStatus(
          country: 'CH',
          fetchedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      await refreshCountryIfStale(fresh, 'CH', now: now);
      expect(fresh.refreshes, isEmpty);

      final stale = FakeRegionRepository(
        status: FeedStatus(
          country: 'CH',
          fetchedAt: now.subtract(const Duration(days: 9)),
        ),
        refreshFailure: const NetworkFailure(),
      );
      // Stale holidays still import when the server cannot be reached.
      await refreshCountryIfStale(stale, 'CH', now: now);
      expect(stale.refreshes, ['CH']);
    });

    Future<List<Region>> readRegions(FakeRegionRepository repository) {
      final container = ProviderContainer(
        overrides: [regionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(countryRegionsProvider('CH'), (_, _) {});
      addTearDown(sub.close);
      return container.read(countryRegionsProvider('CH').future);
    }

    test('a cache without a successful fetch is refreshed', () async {
      // An earlier write broke off: regions, but no fetched_at.
      final repository = FakeRegionRepository(
        status: const FeedStatus(country: 'CH', lastError: 'db 23514'),
      );
      final regions = await readRegions(repository);
      expect(repository.refreshes, ['CH']);
      expect(regions, isNotEmpty);
    });

    test('a failed refresh keeps the regions there are', () async {
      final repository = FakeRegionRepository(
        status: const FeedStatus(country: 'CH', lastError: 'db 23514'),
        refreshFailure: const NetworkFailure(),
      );
      final regions = await readRegions(repository);
      expect(repository.refreshes, ['CH']);
      expect(regions.map((r) => r.code), contains('CH-ZH'));
    });

    test('a fetched cache is not refreshed', () async {
      final repository = FakeRegionRepository(
        status: FeedStatus(country: 'CH', fetchedAt: DateTime(2026, 10, 14)),
      );
      await readRegions(repository);
      expect(repository.refreshes, isEmpty);
    });

    test('a failed first fetch is one error, not retried', () async {
      final repository = FakeRegionRepository(
        regions: const [],
        refreshFailure: const NetworkFailure(),
      );
      await expectLater(
        readRegions(repository),
        throwsA(isA<NetworkFailure>()),
      );
      // Riverpod's default would try again after 200 ms.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(repository.refreshes, ['CH']);
    });
  });

  group('region widgets', () {
    testWidgets(
      'scrolling a region field back uses its name without requests',
      (t) async {
        final repository = FakeRegionRepository(
          status: FeedStatus(country: 'CH', fetchedAt: DateTime.now()),
        );
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await t.pumpWidget(
          ProviderScope(
            overrides: [regionRepositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              locale: const Locale('de'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListView.builder(
                  controller: scroll,
                  itemCount: 30,
                  itemBuilder: (context, i) => i == 0
                      ? RegionField(code: 'CH-ZH', onChanged: (_) {})
                      : const SizedBox(height: 100),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Kanton Zürich (ZH)'), findsOneWidget);
        expect(repository.regionReads, ['CH']);
        expect(repository.statusReads, ['CH']);

        for (var i = 0; i < 3; i++) {
          scroll.jumpTo(1800);
          await t.pumpAndSettle();
          expect(find.byType(RegionField), findsNothing);
          scroll.jumpTo(0);
          // The name is present on the first frame, before any new request could finish.
          await t.pump();
          expect(find.text('Kanton Zürich (ZH)'), findsOneWidget);
          expect(find.text('CH-ZH'), findsNothing);
          await t.pumpAndSettle();
        }
        expect(repository.regionReads, ['CH']);
        expect(repository.statusReads, ['CH']);
        expect(repository.refreshes, isEmpty);

        // Keeping successful results must still allow an explicit reload.
        final container = ProviderScope.containerOf(
          t.element(find.byType(RegionField)),
        );
        container.invalidate(countryRegionsProvider('CH'));
        await t.pumpAndSettle();
        expect(repository.regionReads, ['CH', 'CH']);
        expect(repository.statusReads, ['CH', 'CH']);
      },
    );

    for (final language in ['de', 'en']) {
      testWidgets('cantons use $language labels, Z–A names and code search', (
        t,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        // Unsorted source rows with categories in three different languages.
        final regions = [
          Region.fromJson({
            'code': 'CH-AG',
            'country': 'CH',
            'level': 1,
            'category': 'Kanton',
            'short_name': 'AG',
            'names': {'de': 'Aargau', 'en': 'Aargau'},
          }),
          Region.fromJson({
            'code': 'CH-TI',
            'country': 'CH',
            'level': 1,
            'category': 'cantone',
            'short_name': 'TI',
            'names': {'de': 'Tessin', 'en': 'Ticino'},
          }),
          Region.fromJson({
            'code': 'CH-ZH',
            'country': 'CH',
            'level': 1,
            'category': 'Kanton',
            'short_name': 'ZH',
            'names': {'de': 'Zürich', 'en': 'Zurich'},
          }),
          Region.fromJson({
            'code': 'CH-GE',
            'country': 'CH',
            'level': 1,
            'category': 'canton',
            'short_name': 'GE',
            'names': {'de': 'Genf', 'en': 'Geneva'},
          }),
        ];
        await pumpApp(
          t,
          locale: Locale(language),
          region: FakeRegionRepository(regions: regions),
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
        );
        final probe = await openPicker(t);
        await t.tap(find.text(l10n.regionCountryCH));
        await t.pumpAndSettle();
        final titles = t
            .widgetList<ListTile>(inPicker(find.byType(ListTile)))
            .map((tile) => (tile.title! as Text).data)
            .toList();
        expect(
          titles,
          language == 'de'
              ? [
                  'Kanton Zürich (ZH)',
                  'Kanton Tessin (TI)',
                  'Kanton Genf (GE)',
                  'Kanton Aargau (AG)',
                ]
              : [
                  'Canton Zurich (ZH)',
                  'Canton Ticino (TI)',
                  'Canton Geneva (GE)',
                  'Canton Aargau (AG)',
                ],
        );
        await t.enterText(inPicker(find.byType(TextField)), 'ag');
        await t.pumpAndSettle();
        expect(inPicker(find.byType(ListTile)), findsOneWidget);
        await t.tap(inPicker(find.byType(ListTile)));
        await t.pumpAndSettle();
        expect(probe.pick?.code, 'CH-AG');
      });
    }

    testWidgets('the picker drills country, canton and a Gemeinde search', (
      t,
    ) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      final probe = await openPicker(t);
      await t.tap(find.text(de.regionCountryCH));
      await t.pumpAndSettle();
      await t.tap(find.text('Kanton Zürich (ZH)'));
      await t.pumpAndSettle();
      expect(find.text(de.regionPickWholeRegion('Zürich')), findsOneWidget);

      await t.enterText(inPicker(find.byType(TextField)), 'Uster');
      await t.pumpAndSettle();
      expect(find.text('Wetzikon'), findsNothing);
      // The Gemeinde, listed with its district.
      await t.tap(
        find.ancestor(
          of: find.text('Bezirk Uster'),
          matching: find.byType(ListTile),
        ),
      );
      await t.pumpAndSettle();
      expect(probe.pick?.code, 'CH-ZH-UE-0003');
    });

    testWidgets('a canton without districts is picked at once', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      final probe = await openPicker(t);
      await t.tap(find.text(de.regionCountryCH));
      await t.pumpAndSettle();
      await t.tap(find.text('Kanton Bern (BE)'));
      await t.pumpAndSettle();
      expect(probe.pick?.code, 'CH-BE');
    });

    testWidgets('a country with no cache is fetched before it is listed', (
      t,
    ) async {
      final region = FakeRegionRepository();
      await pumpApp(
        t,
        region: region,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      await openPicker(t);
      await t.tap(find.text(de.regionCountryCH));
      await t.pumpAndSettle();
      expect(region.refreshes, ['CH']);
      expect(find.text('Kanton Bern (BE)'), findsOneWidget);
    });

    testWidgets('a failed fetch offers to go on without a region', (t) async {
      final region = FakeRegionRepository(
        regions: const [],
        refreshFailure: const NetworkFailure(),
      );
      await pumpApp(
        t,
        region: region,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      final probe = await openPicker(t);
      await t.tap(find.text(de.regionCountryCH));
      // Shown at once, not after Riverpod's automatic retries (most of a minute of
      // spinner on a real device): pump a few frames, not pumpAndSettle.
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text(de.regionUnavailable), findsOneWidget);
      expect(region.refreshes, ['CH']);
      await t.tap(find.text(de.regionPickSkip));
      await t.pumpAndSettle();
      expect(probe.done, isTrue);
      expect(probe.pick?.code, isNull);
    });

    testWidgets('the school form saves the region code of the school', (
      t,
    ) async {
      final school = FakeSchoolRepository();
      await pumpApp(
        t,
        school: school,
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          householdSettingsRepositoryProvider.overrideWithValue(FakeSettings()),
        ],
      );
      await openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();

      // Editing only the name keeps the school's region (from the old state code).
      expect(find.text(de.save), findsNothing);
      await t.enterText(find.byType(TextField).first, 'Renamed school');
      await t.pumpAndSettle();
      await t.tap(find.text(de.save));
      await t.pumpAndSettle();
      expect(school.schoolSaves.last.regionCode, 'DE-BE');

      // Another region is picked through the field.
      await t.tap(find.byType(RegionField).first);
      await t.pumpAndSettle();
      await t.tap(find.text(de.regionCountryCH));
      await t.pumpAndSettle();
      await t.tap(find.text('Kanton Bern (BE)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Speichern').first);
      await t.pumpAndSettle();
      expect(school.schoolSaves.last.regionCode, 'CH-BE');
    });

    testWidgets('the first school with a region sets the household region', (
      t,
    ) async {
      final settings = FakeSettings();
      final school = FakeSchoolRepository(
        data: referenceSchoolData(withTimetable: false),
      );
      await pumpApp(
        t,
        school: school,
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          householdSettingsRepositoryProvider.overrideWithValue(settings),
        ],
      );
      await openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiAddSchool));
      await t.pumpAndSettle();

      // A new school proposes the household's region, which is still unset.
      expect(find.text(de.regionFieldEmpty), findsOneWidget);
      await t.tap(find.byType(RegionField).first);
      await t.pumpAndSettle();
      await t.tap(find.text(de.regionCountryCH));
      await t.pumpAndSettle();
      await t.tap(find.text('Kanton Bern (BE)'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Gymnasium');
      await t.pumpAndSettle();
      await t.tap(find.text('Speichern').first);
      await t.pumpAndSettle();

      expect(school.schoolSaves.last.regionCode, 'CH-BE');
      expect(settings.sets, [(key: 'household.region', value: 'CH-BE')]);
    });

    testWidgets('a new school proposes a household region already set', (
      t,
    ) async {
      final settings = FakeSettings(householdRegion: 'CH-ZH-UE-0003');
      await pumpApp(
        t,
        school: FakeSchoolRepository(
          data: referenceSchoolData(withTimetable: false),
        ),
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          householdSettingsRepositoryProvider.overrideWithValue(settings),
        ],
      );
      await openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiAddSchool));
      await t.pumpAndSettle();
      expect(find.text('Uster (Gemeinde), Kanton Zürich (ZH)'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Gymnasium');
      await t.pumpAndSettle();
      await t.tap(find.text('Speichern').first);
      await t.pumpAndSettle();
      // The household has a region already: nothing is written to it.
      expect(settings.sets, isEmpty);
    });

    testWidgets('the import sheet pre-checks free holidays and imports them', (
      t,
    ) async {
      final region = FakeRegionRepository(
        status: FeedStatus(country: 'DE', fetchedAt: DateTime.now()),
      );
      await pumpApp(
        t,
        region: region,
        school: FakeSchoolRepository(
          data: referenceSchoolData(withTimetable: false),
        ),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      await openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(de.regionImportAction));
      await t.tap(find.text(de.regionImportAction));
      await t.pumpAndSettle();

      expect(region.refreshes, isEmpty, reason: 'the status is fresh');
      expect(region.previews.single.region, 'DE-BE');
      expect(find.text('Herbstferien'), findsOneWidget);
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('holiday-feed-herbst')),
            )
            .value,
        isTrue,
      );
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('holiday-feed-weihnacht')),
            )
            .value,
        isFalse,
      );
      expect(find.textContaining(de.regionImportOverlaps), findsOneWidget);
      // Public holidays are applied by the server, not listed here.
      expect(find.text('Allerheiligen'), findsNothing);
      expect(find.text(de.regionImportAttribution), findsOneWidget);

      await t.tap(find.text(de.regionImportButton));
      await t.pumpAndSettle();
      expect(region.imports.single.feedIds, ['feed-herbst']);
      expect(region.imports.single.language, 'de');
      expect(find.text('1 Ferien übernommen'), findsOneWidget);
    });

    testWidgets(
      'a missing cache is refreshed and imported holidays are locked',
      (t) async {
        final region = FakeRegionRepository(
          candidates: referenceCandidates(herbstImported: true),
        );
        await pumpApp(
          t,
          region: region,
          school: FakeSchoolRepository(
            data: referenceSchoolData(withTimetable: false),
          ),
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
        );
        await openSchedule(t);
        await t.tap(find.byTooltip(de.schoolEditSchool));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text(de.regionImportAction));
        await t.tap(find.text(de.regionImportAction));
        await t.pumpAndSettle();

        expect(region.refreshes, ['DE']);
        expect(find.textContaining(de.regionImportAlready), findsOneWidget);
        final imported = t.widget<CheckboxListTile>(
          find.byKey(const ValueKey('holiday-feed-herbst')),
        );
        expect(imported.value, isTrue);
        expect(imported.onChanged, isNull);
        // Nothing importable is left: the import button is off.
        final button = t.widget<FilledButton>(
          find.widgetWithText(FilledButton, de.regionImportButton),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('an imported holiday is marked as imported', (t) async {
      await pumpApp(
        t,
        school: FakeSchoolRepository(
          data: referenceSchoolData(
            withTimetable: false,
            holidays: [
              HolidayRecord.fromJson({
                'id': 'h-1',
                'school_id': 'school-1',
                'name': 'Herbstferien',
                'starts_on': '2026-10-19',
                'ends_on': '2026-10-31',
                'kind': 'holiday',
                'source': 'imported',
              }),
            ],
          ),
        ),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      await openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();
      expect(find.textContaining(de.regionImported), findsOneWidget);
    });

    testWidgets('the settings page offers the region as a household setting', (
      t,
    ) async {
      final settings = FakeSettings();
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          householdSettingsRepositoryProvider.overrideWithValue(settings),
        ],
      );
      container.read(routerProvider).go(Routes.settingsFamily);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('setting-household.region')),
        findsOneWidget,
      );
      expect(find.text(de.regionFieldEmpty), findsOneWidget);
      expect(container.read(householdSettingsProvider).hasValue, isTrue);
    });
  });
}
