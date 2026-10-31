import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/match_correction.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';

/// Einstellungen > Einkaufen > Gelernte Wörter (specs/29, "Learning from the family"):
/// the words whose category the family changed by hand, each with who did it and when,
/// and "Vergessen". Silent to use, visible here; guardians only, in Advanced
/// (`SettingsTile.learnedWords`).
class LearnedWordsSection extends ConsumerWidget {
  const LearnedWordsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final words = ref.watch(matchCorrectionsProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final names = {for (final m in members) m.id: m.displayName};
    return AsyncValueView<List<MatchCorrection>>(
      value: words,
      onRetry: () => ref.invalidate(matchCorrectionsProvider),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: Text(
              list.isEmpty ? l10n.learnedWordsEmpty : l10n.learnedWordsHelp,
              key: const ValueKey('learned-words-help'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          for (final word in list)
            _LearnedWordTile(
              key: ValueKey('learned-word-${word.id}'),
              word: word,
              by: names[word.setBy],
            ),
        ],
      ),
    );
  }
}

class _LearnedWordTile extends ConsumerWidget {
  const _LearnedWordTile({required this.word, required this.by, super.key});

  final MatchCorrection word;
  final String? by;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final category = seededCategoryLabel(l10n, word.key) ?? word.key;
    final date = _shortDate(context, word.setAt.toLocal());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(word.text),
      subtitle: Text(
        by == null
            ? l10n.learnedWordsMeta(category, date)
            : l10n.learnedWordsMetaBy(category, by!, date),
      ),
      trailing: TextButton(
        onPressed: () => _forget(context, ref),
        child: Semantics(
          label: l10n.learnedWordsForgetWord(word.text),
          excludeSemantics: true,
          child: Text(l10n.learnedWordsForget),
        ),
      ),
    );
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final result = await ref
        .read(shoppingRepositoryProvider)
        .forgetMatchCorrection(
          actor: ref.read(actingProfileProvider),
          id: word.id,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(matchCorrectionsProvider);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}

/// "12.11." in this year, with the year before that.
String _shortDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return (date.year == DateTime.now().year
          ? DateFormat.Md(locale)
          : DateFormat.yMd(locale))
      .format(date);
}
