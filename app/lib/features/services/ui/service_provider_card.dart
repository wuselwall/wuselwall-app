import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/services/application/service_actions.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/services/ui/service_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_links.dart';

/// One provider of the services page (ADR-023): what it is, what it costs and offers, and
/// in words what it receives; the switch, its key (write-only) and a test. In Advanced a
/// guardian also chooses what it is used for and its place in the order.
class ServiceProviderCard extends ConsumerStatefulWidget {
  const ServiceProviderCard({
    required this.view,
    required this.canEdit,
    required this.advanced,
    required this.nextPosition,
    this.onMoveUp,
    this.onMoveDown,
    super.key,
  });

  final ServiceProviderView view;

  /// A guardian: the controls work. Everyone else reads the state.
  final bool canEdit;
  final bool advanced;

  /// The position a provider switched on for the first time takes: after the last.
  final int nextPosition;

  /// Null where the provider cannot move that way (not switched on, or at the end).
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  ConsumerState<ServiceProviderCard> createState() =>
      _ServiceProviderCardState();
}

class _ServiceProviderCardState extends ConsumerState<ServiceProviderCard> {
  final _key = TextEditingController();

  /// A stored key is being replaced: the field shows.
  var _replacing = false;
  var _busy = false;

  /// The outcome of the last test: null before one, else works or the words of the error.
  String? _testText;
  var _testOk = false;

  ServiceProviderInfo get _info => widget.view.info;
  ServiceProviderState? get _state => widget.view.state;
  ServiceActions get _actions => ref.read(serviceActionsProvider);

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  /// Runs a write as a guardian; shows a failure, clears the key field on success.
  Future<bool> _write(
    Future<Result<void>> Function() write, {
    bool clearKey = false,
  }) async {
    if (!await ensureGuardian(context, ref) || !mounted) return false;
    setState(() {
      _busy = true;
      _testText = null;
    });
    final result = await write();
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (result.isOk && clearKey) {
        _key.clear();
        _replacing = false;
      }
    });
    if (result case Err(:final failure)) {
      context.showFailure(failure);
      return false;
    }
    return true;
  }

  /// Switching on lists everything the provider offers: one with no capability listed
  /// serves none.
  Future<void> _setEnabled(bool on) => _write(
    () => _actions.setProvider(
      _info.id,
      enabled: on,
      capabilities: on ? _info.capabilities : null,
      position: on && _state == null ? widget.nextPosition : null,
    ),
  );

  Future<void> _saveKey({required bool andSwitchOn}) {
    final text = _key.text.trim();
    if (text.isEmpty) return Future.value();
    return _write(
      () => _actions.setProvider(
        _info.id,
        enabled: andSwitchOn ? true : null,
        capabilities: andSwitchOn ? _info.capabilities : null,
        position: andSwitchOn && _state == null ? widget.nextPosition : null,
        key: text,
      ),
      clearKey: true,
    );
  }

  Future<void> _removeKey() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.serviceKeyRemoveAsk(_info.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.serviceKeyRemove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _write(
      () => _actions.setProvider(_info.id, enabled: false, key: ''),
      clearKey: true,
    );
  }

  Future<void> _setCapability(ServiceCapability c, bool on) {
    final now = _state?.capabilities ?? const <ServiceCapability>[];
    return _write(
      () => _actions.setProvider(
        _info.id,
        capabilities: [
          for (final offered in _info.capabilities)
            if (offered == c ? on : now.contains(offered)) offered,
        ],
      ),
    );
  }

  Future<void> _test() async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !mounted) return;
    setState(() {
      _busy = true;
      _testText = null;
    });
    final result = await _actions.test(_info.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case Ok(:final value):
          _testOk = value.ok;
          _testText = value.ok
              ? l10n.serviceTestOk
              : serviceErrorText(l10n, value.error);
        case Err(:final failure):
          _testOk = false;
          _testText = failure.message(l10n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final info = _info;
    final state = _state;
    final view = widget.view;
    final canEdit = widget.canEdit && !_busy;
    final needsKeyFirst = info.needsKey && !(state?.hasKey ?? false);
    final lastError = view.enabled ? state?.lastError : null;

    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(info.name, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space1,
              children: [
                Chip(
                  label: Text(serviceCostLabel(l10n, info.cost)),
                  visualDensity: VisualDensity.compact,
                ),
                for (final c in info.capabilities)
                  Chip(
                    avatar: Icon(serviceCapabilityIcon(c), size: 18),
                    label: Text(serviceCapabilityLabel(l10n, c)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (info.receives.isNotEmpty) ...[
              const SizedBox(height: Tokens.space2),
              Text(
                l10n.serviceReceivesLine(
                  info.receives
                      .map((r) => serviceReceivesLabel(l10n, r))
                      .join(', '),
                ),
              ),
            ],
            Wrap(
              spacing: Tokens.space2,
              children: [
                if (info.homepage.isNotEmpty)
                  TextButton(
                    onPressed: () => openTripLink(info.homepage),
                    child: Text(l10n.serviceWebsite),
                  ),
                if (info.keyUrl != null)
                  TextButton(
                    onPressed: () => openTripLink(info.keyUrl!),
                    child: Text(l10n.serviceGetKey),
                  ),
              ],
            ),
            if (needsKeyFirst)
              ..._keyEntry(
                l10n,
                canEdit: canEdit,
                label: l10n.serviceKeySaveOn,
                andSwitchOn: true,
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.serviceSwitch),
                value: view.enabled,
                onChanged: canEdit ? _setEnabled : null,
              ),
              if (info.needsKey) ..._storedKey(l10n, canEdit: canEdit),
            ],
            if (lastError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: ww.ink2),
                    const SizedBox(width: Tokens.space2),
                    Expanded(
                      child: Text(
                        l10n.serviceLastError(
                          serviceErrorText(l10n, lastError),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ww.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (view.ready && widget.canEdit)
              Row(
                children: [
                  OutlinedButton(
                    onPressed: canEdit ? _test : null,
                    child: Text(l10n.serviceTest),
                  ),
                  if (_testText != null) ...[
                    const SizedBox(width: Tokens.space3),
                    Icon(
                      _testOk
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: _testOk ? ww.success : theme.colorScheme.error,
                    ),
                    const SizedBox(width: Tokens.space1),
                    Expanded(
                      child: Text(_testText!, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ],
              ),
            if (widget.advanced && view.enabled) ..._advanced(l10n, canEdit),
          ],
        ),
      ),
    );
  }

  /// The field for a key and its save button; never filled in, the key is write-only.
  List<Widget> _keyEntry(
    AppLocalizations l10n, {
    required bool canEdit,
    required String label,
    required bool andSwitchOn,
  }) {
    if (!widget.canEdit) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: Tokens.space2),
          child: Text(l10n.serviceNeedsKeyFirst),
        ),
      ];
    }
    return [
      const SizedBox(height: Tokens.space2),
      TextField(
        controller: _key,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        enabled: canEdit,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: l10n.serviceKeyLabel,
          helperText: l10n.serviceKeyHelp,
          helperMaxLines: 3,
        ),
      ),
      const SizedBox(height: Tokens.space2),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton(
          onPressed: canEdit && _key.text.trim().isNotEmpty
              ? () => _saveKey(andSwitchOn: andSwitchOn)
              : null,
          child: Text(label),
        ),
      ),
    ];
  }

  /// "Key stored …abcd" with replace and remove.
  List<Widget> _storedKey(AppLocalizations l10n, {required bool canEdit}) {
    final hint = _state?.keyHint ?? '';
    return [
      Text(l10n.serviceKeyStored(hint)),
      if (widget.canEdit)
        if (_replacing)
          ..._keyEntry(
            l10n,
            canEdit: canEdit,
            label: l10n.serviceKeySave,
            andSwitchOn: false,
          )
        else
          Wrap(
            spacing: Tokens.space2,
            children: [
              TextButton(
                onPressed: canEdit
                    ? () => setState(() => _replacing = true)
                    : null,
                child: Text(l10n.serviceKeyReplace),
              ),
              TextButton(
                onPressed: canEdit ? _removeKey : null,
                child: Text(l10n.serviceKeyRemove),
              ),
            ],
          ),
    ];
  }

  List<Widget> _advanced(AppLocalizations l10n, bool canEdit) {
    final theme = Theme.of(context);
    final chosen = _state?.capabilities ?? const <ServiceCapability>[];
    return [
      const Divider(),
      if (widget.canEdit) ...[
        Text(l10n.serviceUsedFor, style: theme.textTheme.titleSmall),
        for (final c in _info.capabilities)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(serviceCapabilityLabel(l10n, c)),
            value: chosen.contains(c),
            onChanged: canEdit ? (on) => _setCapability(c, on ?? false) : null,
          ),
        Row(
          children: [
            IconButton(
              tooltip: l10n.serviceMoveUp,
              onPressed: canEdit ? widget.onMoveUp : null,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: l10n.serviceMoveDown,
              onPressed: canEdit ? widget.onMoveDown : null,
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ],
      Text(
        l10n.serviceCallsToday(_state?.callsToday ?? 0),
        style: theme.textTheme.bodySmall?.copyWith(color: context.ww.ink2),
      ),
    ];
  }
}
