import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/identity/ui/pin_keypad.dart';
import 'package:wuselwall/features/setup/ui/qr_scan_page.dart';

/// The guardian's side of J3 (G1, with G2 after it): scan or type the code the new device
/// shows, say what the device is and name it, then approve. Only on a guardian's personal
/// phone (see [canApprovePairingProvider]).
class DevicePairPage extends ConsumerStatefulWidget {
  const DevicePairPage({this.initialKind, this.initialCode, super.key});

  /// Preselected from the getting-started card (connect_tablet, wall_display).
  final PairingKind? initialKind;

  /// A code already read, for a caller that has one.
  final String? initialCode;

  @override
  ConsumerState<DevicePairPage> createState() => _DevicePairPageState();
}

class _DevicePairPageState extends ConsumerState<DevicePairPage> {
  final _typed = TextEditingController();
  final _name = TextEditingController();
  String? _code;
  late PairingKind _kind = widget.initialKind ?? PairingKind.kidTablet;
  String? _childId;
  bool _nameEdited = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code = widget.initialCode == null
        ? null
        : parsePairingCode(widget.initialCode!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncName();
  }

  @override
  void dispose() {
    _typed.dispose();
    _name.dispose();
    super.dispose();
  }

  List<Member> get _children {
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return members.where((m) => !m.isGuardian && m.active).toList();
  }

  /// The chosen child, or the first one while none is chosen.
  String? _effectiveChild(List<Member> children) =>
      children.any((c) => c.id == _childId)
      ? _childId
      : children.firstOrNull?.id;

  /// Fills the name with the kind's default until the guardian types their own.
  void _syncName({List<Member>? children}) {
    if (_nameEdited) return;
    final l10n = context.l10n;
    final list = children ?? _children;
    final child = list.where((c) => c.id == _effectiveChild(list)).firstOrNull;
    _name.text = switch (_kind) {
      PairingKind.wallDisplay => l10n.pairDefaultWall,
      PairingKind.kidTablet => l10n.pairDefaultKid,
      PairingKind.familyTablet => l10n.pairDefaultFamily,
      PairingKind.childPhone =>
        child == null
            ? l10n.pairKindChild
            : l10n.pairDefaultChild(child.displayName),
    };
  }

  // The camera scanner works on phones and the web; desktop builds have no camera API.
  bool get _canScan =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _useCode(String? raw) {
    final code = raw == null ? null : parsePairingCode(raw);
    if (code == null) {
      context.showFailure(const ValidationFailure(code: 'code_invalid'));
      return;
    }
    setState(() => _code = code);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanPage(parse: parsePairingCode),
      ),
    );
    if (code != null && mounted) _useCode(code);
  }

  Future<void> _approve() async {
    final code = _code;
    if (code == null || _busy) return;
    if (!await ensureGuardian(context, ref) || !mounted) return;
    final children = _children;
    final label = _name.text.trim();
    if (label.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref
        .read(pairingRepositoryProvider)
        .approve(
          code: code,
          kind: _kind,
          label: label,
          childProfileId: _kind.bindsChild ? _effectiveChild(children) : null,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok(:final value):
        // G2: the first time a guardian connects a shared device, the PIN is set.
        if (value.needsPin) {
          await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
          if (!mounted) return;
        }
        context.showMessage(context.l10n.pairApproved);
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go(Routes.settings);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final allowed = ref.watch(canApprovePairingProvider);
    final children = _children;
    final childId = _effectiveChild(children);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairConnectAction)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                if (!allowed)
                  Text(l10n.pairOnlyOnPersonal, textAlign: TextAlign.center)
                else if (_code == null)
                  ..._entry(l10n)
                else
                  ..._review(l10n, theme, children, childId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _entry(AppLocalizations l10n) => [
    Text(l10n.pairEntryBody),
    const SizedBox(height: Tokens.space4),
    if (_canScan) ...[
      FilledButton.icon(
        onPressed: _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(l10n.scanQr),
      ),
      const SizedBox(height: Tokens.space4),
    ],
    TextField(
      controller: _typed,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: InputDecoration(labelText: l10n.pairCodeField),
      onSubmitted: (value) => _useCode(value),
    ),
    const SizedBox(height: Tokens.space6),
    FilledButton(
      onPressed: () => _useCode(_typed.text),
      child: Text(l10n.pairNext),
    ),
  ];

  List<Widget> _review(
    AppLocalizations l10n,
    ThemeData theme,
    List<Member> children,
    String? childId,
  ) => [
    Text(l10n.pairReviewBody),
    const SizedBox(height: Tokens.space4),
    FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        formatPairingCode(_code!),
        key: const ValueKey('pair-approve-code'),
        maxLines: 1,
        style: theme.textTheme.displaySmall?.copyWith(
          letterSpacing: 6,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
    const SizedBox(height: Tokens.space2),
    Text(
      l10n.pairConfirmHint,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: Tokens.space6),
    Text(l10n.pairKindLabel, style: theme.textTheme.titleMedium),
    const SizedBox(height: Tokens.space2),
    Wrap(
      spacing: Tokens.space2,
      runSpacing: Tokens.space2,
      children: [
        for (final kind in PairingKind.values)
          ChoiceChip(
            key: ValueKey('pair-kind-${kind.wire}'),
            label: Text(_kindLabel(l10n, kind)),
            selected: _kind == kind,
            onSelected: _busy
                ? null
                : (_) => setState(() {
                    _kind = kind;
                    _syncName(children: children);
                  }),
          ),
      ],
    ),
    if (_kind.bindsChild) ...[
      const SizedBox(height: Tokens.space4),
      DropdownButtonFormField<String>(
        key: const ValueKey('pair-child'),
        initialValue: childId,
        decoration: InputDecoration(labelText: l10n.pairChildLabel),
        items: [
          for (final child in children)
            DropdownMenuItem(value: child.id, child: Text(child.displayName)),
        ],
        onChanged: (value) => setState(() {
          _childId = value;
          _syncName(children: children);
        }),
      ),
    ],
    const SizedBox(height: Tokens.space4),
    TextField(
      key: const ValueKey('pair-name'),
      controller: _name,
      decoration: InputDecoration(labelText: l10n.pairNameLabel),
      onChanged: (_) => _nameEdited = true,
    ),
    const SizedBox(height: Tokens.space6),
    FilledButton(
      onPressed: _busy ? null : _approve,
      child: Text(l10n.pairApproveAction),
    ),
  ];

  String _kindLabel(AppLocalizations l10n, PairingKind kind) => switch (kind) {
    PairingKind.wallDisplay => l10n.pairKindWall,
    PairingKind.kidTablet => l10n.pairKindKid,
    PairingKind.familyTablet => l10n.pairKindFamily,
    PairingKind.childPhone => l10n.pairKindChild,
  };
}

/// G2: the guardian PIN, entered twice on the numeric pad. Pops true once it is set.
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  static const _length = 6;
  String _digits = '';
  String? _first;
  String? _error;
  bool _busy = false;

  void _digit(String digit) {
    if (_busy || _digits.length >= _length) return;
    setState(() {
      _digits += digit;
      _error = null;
    });
    if (_digits.length == _length) unawaited(_complete());
  }

  void _backspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _complete() async {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = _digits;
        _digits = '';
      });
      return;
    }
    if (first != _digits) {
      setState(() {
        _first = null;
        _digits = '';
        _error = context.l10n.pairPinMismatch;
      });
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .setPin(pin: _digits);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _busy = false;
          _first = null;
          _digits = '';
        });
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairPinTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              shrinkWrap: true,
              children: [
                Text(
                  _first == null ? l10n.pairPinBody : l10n.pairPinConfirm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Tokens.space4),
                PinDots(length: _length, filled: _digits.length),
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(
                      _error ?? '',
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                PinKeypad(
                  enabled: !_busy,
                  onDigit: _digit,
                  onBackspace: _backspace,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
