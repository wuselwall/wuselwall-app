import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/features/region/application/region_providers.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';
import 'package:wuselwall/features/region/ui/region_text.dart';

/// Opens the region picker full screen. The result is the chosen [RegionPick] (its code is
/// null for "no region"); dismissing it gives null, and the caller keeps what it had.
Future<RegionPick?> showRegionPicker(BuildContext context, {String? current}) =>
    Navigator.of(context, rootNavigator: true).push<RegionPick>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RegionPickerPage(current: current),
      ),
    );

/// Three steps: the country, then its canton or Bundesland (searchable), then either that
/// region itself or, for a region with districts or municipalities, a search over all of
/// them ("Uster" finds the Gemeinde in Kanton Zürich). "Anderes Land" picks no region.
class RegionPickerPage extends ConsumerStatefulWidget {
  const RegionPickerPage({this.current, super.key});

  /// The code the field holds now; the picker does not change it.
  final String? current;

  @override
  ConsumerState<RegionPickerPage> createState() => _RegionPickerPageState();
}

class _RegionPickerPageState extends ConsumerState<RegionPickerPage> {
  String? _country;
  Region? _top;
  String _query = '';

  void _pick(String? code) => Navigator.of(context).pop(RegionPick(code));

  void _back() {
    setState(() {
      if (_top != null) {
        _top = null;
      } else {
        _country = null;
      }
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = _top;
    final country = _country;
    final title = top != null
        ? regionHeading(l10n, top, languageOf(context))
        : country != null
        ? l10n.regionPickRegionTitle
        : l10n.regionPickCountryTitle;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: country == null
            ? CloseButton(onPressed: () => Navigator.of(context).pop())
            : BackButton(onPressed: _back),
      ),
      body: top != null
          ? _deeperStep(context, country!, top)
          : country != null
          ? _topStep(context, country)
          : _countryStep(context),
    );
  }

  Widget _countryStep(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      children: [
        for (final code in regionCountries)
          ListTile(
            title: Text(regionCountryName(l10n, code)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _country = code),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(l10n.regionCountryOther),
          onTap: () => _pick(null),
        ),
      ],
    );
  }

  /// The canton or Bundesland step, loaded from the country's cache.
  Widget _topStep(BuildContext context, String country) {
    final regions = ref.watch(countryRegionsProvider(country));
    return switch (regions) {
      AsyncData(:final value) => _topList(context, country, value),
      AsyncError() => _Unavailable(
        onRetry: () => ref.invalidate(countryRegionsProvider(country)),
        onSkip: () => _pick(null),
      ),
      _ => const _Loading(),
    };
  }

  Widget _topList(BuildContext context, String country, List<Region> all) {
    final l10n = context.l10n;
    final language = languageOf(context);
    final index = RegionIndex(all);
    final needle = fold(_query);
    final tops =
        [
          for (final r in all)
            if (r.level == 1 &&
                (fold(r.displayName(language)).contains(needle) ||
                    fold(r.shortName).contains(needle)))
              r,
        ]..sort(
          (a, b) =>
              fold(b.displayName(language))
                  .compareTo(fold(a.displayName(language))),
        );
    return Column(
      children: [
        _SearchField(
          label: l10n.regionPickSearch,
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: tops.isEmpty
              ? Center(
                  child: Text(
                    all.isEmpty ? l10n.regionPickEmpty : l10n.regionPickNoMatch,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: tops.length,
                  itemBuilder: (context, i) {
                    final r = tops[i];
                    return ListTile(
                      title: Text(regionHeading(l10n, r, language)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Without districts or municipalities there is nothing to choose.
                        if (index.below(r.code).isEmpty) {
                          _pick(r.code);
                        } else {
                          setState(() {
                            _top = r;
                            _query = '';
                          });
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The region itself, or a search over the districts and municipalities below it.
  Widget _deeperStep(BuildContext context, String country, Region top) {
    final l10n = context.l10n;
    final language = languageOf(context);
    final all = ref.watch(countryRegionsProvider(country)).value ?? const [];
    final index = RegionIndex(all);
    final needle = fold(_query);
    final hits =
        [
          for (final r in index.below(top.code))
            if (fold(r.displayName(language)).contains(needle)) r,
        ]..sort(
          (a, b) => a.displayName(language).compareTo(b.displayName(language)),
        );
    final topName = top.displayName(language);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(l10n.regionPickWholeRegion(topName)),
          onTap: () => _pick(top.code),
        ),
        if (index.below(top.code).isNotEmpty) ...[
          const Divider(height: 1),
          _SearchField(
            label: l10n.regionPickDeeperSearch,
            heading: l10n.regionPickDeeperTitle,
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: hits.isEmpty
                ? Center(child: Text(l10n.regionPickNoMatch))
                : ListView.builder(
                    itemCount: hits.length,
                    itemBuilder: (context, i) {
                      final r = hits[i];
                      final parent = index.parentOf(r);
                      return ListTile(
                        title: Text(r.displayName(language)),
                        subtitle: parent == null
                            ? null
                            : Text(regionHeading(l10n, parent, language)),
                        onTap: () => _pick(r.code),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.label,
    required this.onChanged,
    this.heading,
  });

  final String label;
  final String? heading;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              heading!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: label,
          ),
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(context.l10n.regionPickLoading),
      ],
    ),
  );
}

/// The regions could not be fetched: say so, offer a retry, or go on without a region.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry, required this.onSkip});

  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(l10n.regionUnavailable, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.regionPickRetry),
            ),
            TextButton(onPressed: onSkip, child: Text(l10n.regionPickSkip)),
          ],
        ),
      ),
    );
  }
}
