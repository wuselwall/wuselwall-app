import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
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
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The question of this moment for this device, with its window, or null.
({TableQuestion question, int window})? _current(
  BuildContext context,
  WidgetRef ref,
) {
  final lang = Localizations.localeOf(context).languageCode;
  final moment = ref.watch(tableMomentProvider(lang));
  if (moment == null) return null;
  final skip = ref.watch(tableSkipProvider)[moment.window] ?? 0;
  final q = householdQuestion(
    moment.questions,
    moment.householdId,
    moment.window,
    cycleLength: moment.cycleLength,
    skip: skip,
  );
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

/// The size of the wall's question: 34 (specs/27 asks for 34 or more), smaller only
/// when the question would not fit three lines of [width] at that size, as a long
/// question of the family's own might; past the smallest size it ends in an ellipsis.
@visibleForTesting
double boardQuestionSize(
  String text, {
  required double width,
  required TextStyle Function(double size) style,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) {
  for (final size in const [34.0, 30.0, 26.0]) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style(size)),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 3,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    if (fits) return size;
  }
  return 22;
}

/// The width the header leaves the question: the screen less the clock, the date, the
/// corner Wusel, the settings button and the card's own buttons. An estimate on
/// purpose: the header sizes itself by its intrinsic height, which a LayoutBuilder
/// cannot report.
double _boardQuestionWidth(BuildContext context, {required int buttons}) =>
    math.max(240, MediaQuery.sizeOf(context).width - 680 - 56.0 * buttons);

/// The wall's Tischfrage, in the header's middle during the meal (specs/27): the
/// question is large, "Andere Frage" is a full 56 px target, and a riddle's answer opens
/// below the question rather than beside it, so it never pushes the header apart. The
/// corner Wusel of the header is the one that holds it (specs/25: one Wusel per screen).
/// The week stays on screen.
class BoardTableQuestion extends ConsumerStatefulWidget {
  const BoardTableQuestion({super.key});

  @override
  ConsumerState<BoardTableQuestion> createState() => _BoardTableQuestionState();
}

class _BoardTableQuestionState extends ConsumerState<BoardTableQuestion> {
  /// The question whose answer is open; another question starts closed.
  String? _answerOf;

  @override
  Widget build(BuildContext context) {
    final current = _current(context, ref);
    if (current == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final q = current.question;
    final ink = Theme.of(context).colorScheme.onSurface;
    final author = _author(ref, q);
    final shown = _answerOf == q.key;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow
            .withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: l10n.tableQuestionTitle,
                  child: Text(
                    q.text,
                    key: const ValueKey('board-table-question'),
                    style: boardUi(
                      boardQuestionSize(
                        q.text,
                        width: _boardQuestionWidth(
                          context,
                          buttons: q.answer == null ? 1 : 2,
                        ),
                        style: (size) => boardUi(size, weight: FontWeight.w700),
                        textScaler: MediaQuery.textScalerOf(context),
                        textDirection: Directionality.of(context),
                      ),
                      weight: FontWeight.w700,
                      color: ink,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (author != null)
                  Text(
                    l10n.tableQuestionFrom(author),
                    style: boardUi(22, weight: FontWeight.w600, color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (shown && q.answer != null)
                  Text(
                    q.answer!,
                    key: const ValueKey('board-table-answer'),
                    style: boardUi(26, weight: FontWeight.w700, color: ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (q.answer != null)
            IconButton(
              tooltip: l10n.tableQuestionAnswer,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              iconSize: 30,
              isSelected: shown,
              icon: const Icon(Icons.lightbulb_outline),
              selectedIcon: const Icon(Icons.lightbulb),
              onPressed: () => setState(() => _answerOf = shown ? null : q.key),
            ),
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
    // Put away on Today until the next meal; local to this device (specs/27).
    if (!kid && ref.watch(tableDismissProvider).contains(current.window)) {
      return const SizedBox.shrink();
    }
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tableQuestionTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: context.ww.ink2,
                    ),
                  ),
                ),
                if (!kid)
                  IconButton(
                    key: const ValueKey('table-question-dismiss'),
                    tooltip: l10n.tableQuestionDismiss,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    onPressed: () => ref
                        .read(tableDismissProvider.notifier)
                        .dismiss(current.window),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
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
                // Anyone may add a question of their own, children too.
                TextButton(
                  onPressed: () => unawaited(openFamilyQuestions(context)),
                  child: Text(
                    kid ? l10n.tableQuestionAdd : l10n.tableQuestionsManage,
                  ),
                ),
                // Hiding a bundled question is a guardian's (api.table_question_hide).
                if (!kid && !q.isOwn && _isGuardian(ref))
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
    final container = ProviderScope.containerOf(context);
    final result = await container
        .read(ritualsRepositoryProvider)
        .hideQuestion(actor: container.read(actingProfileProvider), key: q.key);
    container.invalidate(familyQuestionsProvider);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

/// A riddle's answer, behind a tap.
class _AnswerButton extends StatefulWidget {
  const _AnswerButton({required this.answer});

  final String answer;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _shown = !_shown),
    child: Text(
      _shown ? widget.answer : context.l10n.tableQuestionAnswer,
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

/// Opens the family's own questions: from the table question's card, and from the
/// household settings' Rituale.
Future<void> openFamilyQuestions(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const FamilyQuestionsPage()));

/// The way to the family's own questions under Einstellungen → Rituale, at any time of
/// day. Not on the wall, which writes no questions, nor against a server without them.
class FamilyQuestionsTile extends ConsumerWidget {
  const FamilyQuestionsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(lighterDaySupportedProvider) ||
        ref.watch(uiRegisterProvider) == UiRegister.kiosk) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('family-questions'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.forum_outlined),
      title: Text(l10n.tableQuestionsManage),
      subtitle: Text(l10n.tableQuestionAddHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(openFamilyQuestions(context)),
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
    final container = ProviderScope.containerOf(context);
    setState(() => _busy = true);
    final result = await call();
    container.invalidate(familyQuestionsProvider);
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
    final guardian = _isGuardian(ref);
    final own = [
      for (final q in rows)
        if (q.text != null) q,
    ];
    // Showing a hidden question again is a guardian's, like hiding it.
    final hidden = [
      if (guardian)
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
              // The author or a guardian removes a question (api.table_question_remove).
              trailing: guardian || (actor != null && q.createdBy == actor)
                  ? IconButton(
                      tooltip: l10n.tableQuestionRemove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => repo.removeQuestion(actor: actor, id: q.id),
                            ),
                    )
                  : null,
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

/// Whether the person at the device is a guardian.
bool _isGuardian(WidgetRef ref) {
  final acting = ref.watch(actingProfileProvider);
  return ref
          .watch(membersProvider)
          .value
          ?.where((m) => m.id == acting)
          .firstOrNull
          ?.isGuardian ??
      false;
}
