import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// The language of this installation, or the device's (specs/09). Not a guardian action:
/// it changes nothing for anyone else.
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chosen = ref.watch(appLanguageProvider).value;
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.languageTitle),
      subtitle: Text(_label(context, l10n, chosen)),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _LanguageDialog(),
      ),
    );
  }
}

class _LanguageDialog extends ConsumerWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chosen = ref.watch(appLanguageProvider).value;
    return AlertDialog(
      title: Text(l10n.languageTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: Tokens.space4),
      content: SingleChildScrollView(
        // The device's language is the empty value: a RadioGroup cannot carry null.
        child: RadioGroup<String>(
          groupValue: chosen?.languageCode ?? '',
          onChanged: (value) {
            if (value == null) return;
            ref
                .read(appLanguageProvider.notifier)
                .select(value.isEmpty ? null : Locale(value));
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: '',
                title: Text(l10n.languageSystem),
                subtitle: Text(l10n.languageSystemHelp),
              ),
              for (final locale in supportedLocales)
                RadioListTile<String>(
                  value: locale.languageCode,
                  title: Text(_name(l10n, locale)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// The tile names the language in effect: the chosen one, or the device's as resolved.
String _label(BuildContext context, AppLocalizations l10n, Locale? chosen) =>
    chosen == null
    ? l10n.languageSystemCurrent(_name(l10n, Localizations.localeOf(context)))
    : _name(l10n, chosen);

/// Each language in its own name, so a reader finds theirs whatever is shown now.
String _name(AppLocalizations l10n, Locale locale) =>
    switch (locale.languageCode) {
      'en' => l10n.languageNameEn,
      'fr' => l10n.languageNameFr,
      'es' => l10n.languageNameEs,
      _ => l10n.languageNameDe,
    };
