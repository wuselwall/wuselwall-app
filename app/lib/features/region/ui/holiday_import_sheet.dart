import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/region/application/holiday_import_providers.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';
import 'package:wuselwall/features/region/ui/region_text.dart';

/// Opens the school-holiday import for [target]. The result is how many holidays were
/// imported, or null when the sheet was closed.
Future<int?> showHolidayImportSheet(
  BuildContext context,
  HolidayImportTarget target,
) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => HolidayImportSheet(target: target),
);

/// Lists the school holidays of the region as checkboxes and imports the ticked ones. Public
/// holidays are not listed: the server applies them from the region. Rows already imported
/// are shown and locked; rows that overlap a holiday the household entered are unticked.
class HolidayImportSheet extends ConsumerStatefulWidget {
  const HolidayImportSheet({required this.target, super.key});

  final HolidayImportTarget target;

  @override
  ConsumerState<HolidayImportSheet> createState() => _HolidayImportSheetState();
}

class _HolidayImportSheetState extends ConsumerState<HolidayImportSheet> {
  /// The feed ids ticked by the user; null until the first list is on screen.
  Set<String>? _chosen;
  bool _busy = false;

  String get _country => widget.target.region.split('-').first;

  Future<void> _import(List<HolidayCandidate> candidates) async {
    final ids = [
      for (final c in candidates)
        if (!c.alreadyImported && (_chosen ?? const {}).contains(c.feedId))
          c.feedId,
    ];
    setState(() => _busy = true);
    final result = await ref
        .read(regionRepositoryProvider)
        .importHolidays(
          actor: ref.read(actingProfileProvider),
          schoolId: widget.target.schoolId,
          feedIds: ids,
          language: languageOf(context),
        );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final candidates = ref.watch(holidayCandidatesProvider(widget.target));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Tokens.space4,
          right: Tokens.space4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.regionImportTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Tokens.space2),
            Text(l10n.regionImportIntro),
            if (_country == 'CH') ...[
              const SizedBox(height: Tokens.space2),
              _Note(text: l10n.regionImportSwissHint),
            ],
            const SizedBox(height: Tokens.space3),
            Flexible(
              child: AsyncValueView<List<HolidayCandidate>>(
                value: candidates,
                onRetry: () =>
                    ref.invalidate(holidayCandidatesProvider(widget.target)),
                data: (all) => _list(context, all),
              ),
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              l10n.regionImportAttribution,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<HolidayCandidate> all) {
    final l10n = context.l10n;
    final language = languageOf(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final holidays = [
      for (final c in all)
        if (c.isSchoolHoliday) c,
    ];
    // The first list sets the ticks: free holidays on, overlapping ones off.
    final chosen = _chosen ??= {
      for (final c in holidays)
        if (!c.alreadyImported && !c.overlapsExisting) c.feedId,
    };
    final importable = [
      for (final c in holidays)
        if (!c.alreadyImported && chosen.contains(c.feedId)) c,
    ];
    if (holidays.isEmpty) {
      return Center(child: Text(l10n.regionImportNone));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in holidays)
                CheckboxListTile(
                  key: ValueKey('holiday-${c.feedId}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.displayName(language)),
                  subtitle: Text(
                    [
                      _range(c, locale),
                      if (c.alreadyImported) l10n.regionImportAlready,
                      if (c.overlapsExisting && !c.alreadyImported)
                        l10n.regionImportOverlaps,
                    ].join(' · '),
                  ),
                  value: c.alreadyImported || chosen.contains(c.feedId),
                  onChanged: _busy || c.alreadyImported
                      ? null
                      : (on) => setState(() {
                          if (on == true) {
                            chosen.add(c.feedId);
                          } else {
                            chosen.remove(c.feedId);
                          }
                        }),
                ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space2),
        FilledButton(
          onPressed: _busy || importable.isEmpty ? null : () => _import(all),
          child: Text(l10n.regionImportButton),
        ),
      ],
    );
  }

  String _range(HolidayCandidate c, String locale) =>
      '${DateFormat.Md(locale).format(c.startsOn)}–'
      '${DateFormat.yMd(locale).format(c.endsOn)}';
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.space2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
    );
  }
}
