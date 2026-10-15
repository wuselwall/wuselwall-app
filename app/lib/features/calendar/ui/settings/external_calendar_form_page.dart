import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/application/external_calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';
import 'package:wuselwall/features/calendar/ui/external_calendar_text.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// Subscribe to a calendar, or change one (guardians only). Saving fetches the feed at
/// once, so the result is shown before the list comes back.
class ExternalCalendarFormPage extends ConsumerStatefulWidget {
  const ExternalCalendarFormPage({this.calendar, super.key});

  /// Null for a new subscription.
  final ExternalCalendar? calendar;

  @override
  ConsumerState<ExternalCalendarFormPage> createState() =>
      _ExternalCalendarFormPageState();
}

class _ExternalCalendarFormPageState
    extends ConsumerState<ExternalCalendarFormPage> {
  late final _name = TextEditingController(text: widget.calendar?.name ?? '');
  final _url = TextEditingController();

  /// The address the server holds, once a guardian's edit form has loaded it. Null for a
  /// new subscription or when the load failed; a save sends the address only when it
  /// differs from this, so an untouched address is never sent back.
  String? _storedUrl;

  /// Editing: the full address is still being fetched from `external_calendar_url`.
  late bool _urlLoading = widget.calendar != null;
  late String _colour =
      widget.calendar?.colourHex ?? toHex(MemberPalette.swatches.first.light);
  late final Set<String> _members = {...?widget.calendar?.memberIds};
  late bool _showOnBoard = widget.calendar?.showOnBoard ?? false;
  String? _nameError;
  String? _urlError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.calendar != null) unawaited(_loadUrl());
  }

  Future<void> _loadUrl() async {
    final result = await ref
        .read(externalCalendarsRepositoryProvider)
        .url(actor: ref.read(actingProfileProvider), id: widget.calendar!.id);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        setState(() {
          _storedUrl = value;
          _url.text = value;
          _urlLoading = false;
        });
      case Err(:final failure):
        setState(() => _urlLoading = false);
        context.showFailure(failure);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final url = normalizeCalendarUrl(_url.text);
    setState(() {
      _nameError = name.isEmpty ? l10n.extCalNameRequired : null;
      _urlError = url == null ? l10n.extCalUrlInvalid : null;
    });
    if (name.isEmpty || url == null) return;
    if (!await ensureGuardian(context, ref) || !mounted) return;

    setState(() => _saving = true);
    final repo = ref.read(externalCalendarsRepositoryProvider);
    final actor = ref.read(actingProfileProvider);
    final saved = await repo.save(
      actor: actor,
      draft: ExternalCalendarDraft(
        id: widget.calendar?.id,
        name: name,
        url: url == _storedUrl ? null : url,
        colourHex: _colour,
        memberIds: _members.toList(),
        showOnBoard: _showOnBoard,
      ),
    );
    if (!mounted) return;
    if (saved case Err(:final failure)) {
      setState(() => _saving = false);
      context.showFailure(failure);
      return;
    }
    final id = saved.valueOrNull!;
    final refreshed = await repo.refresh(actor: actor, calendarId: id);
    if (!mounted) return;
    ref
      ..invalidate(externalCalendarsProvider)
      ..invalidate(occurrencesProvider);
    switch (refreshed) {
      case Ok(:final value):
        context.showMessage(refreshResultText(l10n, value));
      case Err(:final failure):
        context.showFailure(failure);
    }
    context.go(Routes.externalCalendars);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final editing = widget.calendar != null;
    final members = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.active)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? l10n.extCalEditTitle : l10n.extCalNewTitle),
        leading: BackButton(
          onPressed: () => context.go(Routes.externalCalendars),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          TextField(
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _nameError = null),
            decoration: InputDecoration(
              labelText: l10n.extCalNameLabel,
              hintText: l10n.extCalNameHint,
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: _url,
            enabled: !_urlLoading,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _urlError = null),
            decoration: InputDecoration(
              labelText: l10n.extCalUrlLabel,
              errorText: _urlError,
              suffixIcon: _urlLoading
                  ? Semantics(
                      label: l10n.extCalUrlLoading,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            l10n.extCalUrlHelp,
            style: text.bodySmall?.copyWith(color: ww.ink2),
          ),
          const SizedBox(height: Tokens.space4),
          Text(l10n.extCalColourLabel, style: text.labelLarge),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              for (final (i, swatch) in MemberPalette.swatches.indexed)
                _ColourChoice(
                  colour: swatch.light,
                  hex: toHex(swatch.light),
                  selected: _colour == toHex(swatch.light),
                  label: l10n.extCalColourOption(i + 1),
                  onTap: () => setState(() => _colour = toHex(swatch.light)),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          Text(l10n.extCalMembersLabel, style: text.labelLarge),
          Text(
            l10n.extCalMembersHelp,
            style: text.bodySmall?.copyWith(color: ww.ink2),
          ),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              for (final m in members)
                FilterChip(
                  showCheckmark: false,
                  avatar: RingedAvatar(
                    selected: _members.contains(m.id),
                    child: MemberDot(
                      memberColor: m.color,
                      semanticLabel: m.displayName,
                      size: 16,
                    ),
                  ),
                  label: Text(m.displayName),
                  selected: _members.contains(m.id),
                  onSelected: (on) => setState(
                    () => on ? _members.add(m.id) : _members.remove(m.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.extCalShowOnBoard),
            subtitle: Text(l10n.extCalShowOnBoardHelp),
            value: _showOnBoard,
            onChanged: (on) => setState(() => _showOnBoard = on),
          ),
          const SizedBox(height: Tokens.space4),
          FilledButton(
            onPressed: _saving || _urlLoading ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// One colour of the member palette, as a round choice with a check when chosen.
class _ColourChoice extends StatelessWidget {
  const _ColourChoice({
    required this.colour,
    required this.hex,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color colour;
  final String hex;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final cs = Theme.of(context).colorScheme;
    final member = ww.member(colour);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: member.ink,
            border: Border.all(
              color: selected ? cs.onSurface : member.ink,
              width: 3,
            ),
          ),
          child: selected ? Icon(Icons.check, color: member.onInk) : null,
        ),
      ),
    );
  }
}
