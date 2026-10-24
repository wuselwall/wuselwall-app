import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/table_question.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// The question of this moment for this device, with its window, or null.
({TableQuestion question, int window})? _current(
  BuildContext context,
  WidgetRef ref,
) {
  final lang = Localizations.localeOf(context).languageCode;
  final moment = ref.watch(tableMomentProvider(lang));
  if (moment == null) return null;
  final skip = ref.watch(tableSkipProvider)[moment.window] ?? 0;
  final q = questionFor(moment.questions, moment.window, skip: skip);
  return q == null ? null : (question: q, window: moment.window);
}

String? _author(WidgetRef ref, TableQuestion q) {
  if (q.authorId == null) return null;
  return ref
      .watch(membersProvider)
      .value
      ?.where((m) => m.id == q.authorId)
      .firstOrNull
      ?.displayName;
}

/// The wall's Tischfrage, in the header's middle during the meal (specs/27): Wusel
/// holds it, the question is large, "Andere Frage" is a full 56 px target. The week
/// stays on screen.
class BoardTableQuestion extends ConsumerWidget {
  const BoardTableQuestion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _current(context, ref);
    if (current == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final q = current.question;
    final ink = Theme.of(context).colorScheme.onSurface;
    final author = _author(ref, q);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow
            .withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const FamilyWusel(size: 52),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: l10n.tableQuestionTitle,
              child: Text(
                author == null
                    ? q.text
                    : '${q.text}  ${l10n.tableQuestionFrom(author)}',
                style: boardUi(26, weight: FontWeight.w700, color: ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (q.answer != null) _AnswerButton(answer: q.answer!, board: true),
          IconButton(
            tooltip: l10n.tableQuestionNext,
            constraints: const BoxConstraints.tightFor(width: 56, height: 56),
            iconSize: 30,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(tableSkipProvider.notifier).next(current.window),
          ),
        ],
      ),
    );
  }
}

/// The Tischfrage as a card, for the kid tablet and Today.
class TableQuestionCard extends ConsumerWidget {
  const TableQuestionCard({this.kid = false, super.key});

  final bool kid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _current(context, ref);
    if (current == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final q = current.question;
    final author = _author(ref, q);
    final band = context.ww.band(AppModule.meals);
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space3),
      child: Container(
        padding: const EdgeInsets.all(Tokens.space4),
        decoration: BoxDecoration(
          color: band,
          borderRadius: BorderRadius.circular(kid ? 22 : 12),
          border: Border.all(color: context.ww.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tableQuestionTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.ww.ink2,
              ),
            ),
            const SizedBox(height: Tokens.space2),
            Row(
              children: [
                FamilyWusel(size: kid ? 88 : 56, quietAllowed: true),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.text,
                        style:
                            (kid
                                    ? theme.textTheme.headlineSmall
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (author != null)
                        Text(
                          l10n.tableQuestionFrom(author),
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.tableQuestionNext),
                  onPressed: () =>
                      ref.read(tableSkipProvider.notifier).next(current.window),
                ),
                if (q.answer != null) _AnswerButton(answer: q.answer!),
                if (!kid)
                  TextButton(
                    onPressed: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FamilyQuestionsPage(),
                        ),
                      ),
                    ),
                    child: Text(l10n.tableQuestionsManage),
                  ),
                if (!kid && !q.isOwn)
                  TextButton(
                    onPressed: () => unawaited(_hide(context, ref, q)),
                    child: Text(l10n.tableQuestionHide),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hide(
    BuildContext context,
    WidgetRef ref,
    TableQuestion q,
  ) async {
    final result = await ref
        .read(ritualsRepositoryProvider)
        .hideQuestion(actor: ref.read(actingProfileProvider), key: q.key);
    ref.invalidate(familyQuestionsProvider);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

/// A riddle's answer, behind a tap.
class _AnswerButton extends StatefulWidget {
  const _AnswerButton({required this.answer, this.board = false});

  final String answer;
  final bool board;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = widget.board
        ? boardUi(24, weight: FontWeight.w700)
        : Theme.of(context).textTheme.titleMedium;
    return TextButton(
      style: widget.board
          ? TextButton.styleFrom(minimumSize: const Size(56, 56))
          : null,
      onPressed: () => setState(() => _shown = !_shown),
      child: Text(
        _shown ? widget.answer : l10n.tableQuestionAnswer,
        style: style,
      ),
    );
  }
}

/// The family's own questions and the bundled ones it hid (specs/27). Anyone adds
/// one; the author or a guardian removes it; a guardian shows a hidden one again.
class FamilyQuestionsPage extends ConsumerStatefulWidget {
  const FamilyQuestionsPage({super.key});

  @override
  ConsumerState<FamilyQuestionsPage> createState() =>
      _FamilyQuestionsPageState();
}

class _FamilyQuestionsPageState extends ConsumerState<FamilyQuestionsPage> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Result<void>> Function() call) async {
    setState(() => _busy = true);
    final result = await call();
    ref.invalidate(familyQuestionsProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repo = ref.read(ritualsRepositoryProvider);
    final actor = ref.watch(actingProfileProvider);
    final rows = ref.watch(familyQuestionsProvider).value ?? const [];
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final lang = Localizations.localeOf(context).languageCode;
    final bundled = {
      for (final q
          in ref.watch(bundledDeckProvider(lang)).value ??
              const <TableQuestion>[])
        q.key: q.text,
    };
    final own = [
      for (final q in rows)
        if (q.text != null) q,
    ];
    final hidden = [
      for (final q in rows)
        if (q.hiddenKey != null) q,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tableQuestionsManage)),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          TextField(
            key: const ValueKey('own-question'),
            controller: _text,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.tableQuestionAdd,
              hintText: l10n.tableQuestionAddHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: _busy || _text.text.trim().isEmpty
                  ? null
                  : () async {
                      final text = _text.text;
                      _text.clear();
                      await _run(
                        () => repo.addQuestion(actor: actor, text: text),
                      );
                    },
              child: Text(l10n.tableQuestionAdd),
            ),
          ),
          const SizedBox(height: Tokens.space4),
          for (final q in own)
            ListTile(
              title: Text(q.text!),
              subtitle: q.createdBy == null || names[q.createdBy] == null
                  ? null
                  : Text(l10n.tableQuestionFrom(names[q.createdBy]!)),
              trailing: IconButton(
                tooltip: l10n.tableQuestionRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => repo.removeQuestion(actor: actor, id: q.id),
                      ),
              ),
            ),
          if (hidden.isNotEmpty) ...[
            const Divider(),
            Text(
              l10n.tableQuestionsHidden,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final q in hidden)
              ListTile(
                title: Text(bundled[q.hiddenKey] ?? q.hiddenKey!),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => repo.hideQuestion(
                            actor: actor,
                            key: q.hiddenKey!,
                            hidden: false,
                          ),
                        ),
                  child: Text(l10n.tableQuestionShowAgain),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
