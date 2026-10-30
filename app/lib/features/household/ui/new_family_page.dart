import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/application/household_providers.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/device_label.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/setup/ui/busy_button_label.dart';

/// H1 "Neue Familie" (specs/20, J1): the one screen between sign-in and a household. The
/// family name, the person's name and colour are prefilled from the account; the time zone
/// and language come from the device, and the founder code is asked only in `code` mode.
class NewFamilyPage extends ConsumerStatefulWidget {
  const NewFamilyPage({this.account, super.key});

  /// The account the router is showing this page for; null only while a Ready session
  /// rebuilds the page during creation.
  final Account? account;

  @override
  ConsumerState<NewFamilyPage> createState() => _NewFamilyPageState();
}

class _NewFamilyPageState extends ConsumerState<NewFamilyPage> {
  final _form = GlobalKey<FormState>();
  final _family = TextEditingController();
  final _name = TextEditingController();
  final _founderCode = TextEditingController();
  late final bool _needsCode;
  String? _setupCode;
  var _loadingSetup = true;
  var _seeded = false;
  var _swatch = 0;
  var _examples = true;
  var _busy = false;

  /// True while the create request runs: the button says so with a spinner.
  var _creating = false;
  // Set when the session has not turned Ready long after create() succeeded: the form
  // stays locked (a second create would make a second family), but the escapes open again.
  var _stalled = false;
  Timer? _stallTimer;
  Timer? _setupExpiryTimer;
  String? _codeError;

  /// The household default until the device says otherwise.
  var _timezone = 'Europe/Berlin';

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _needsCode = account?.creation != HouseholdCreation.open;
    _name.text = account?.givenName ?? '';
    unawaited(_loadTimezone());
    unawaited(_loadSetup());
    _setupExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_busy) unawaited(_loadSetup());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      final surname = widget.account?.suggestedFamilyName;
      if (surname != null) {
        _family.text = context.l10n.householdNewFamilyPrefill(surname);
      }
    }
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _setupExpiryTimer?.cancel();
    for (final c in [_family, _name, _founderCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSetup() async {
    final server = Uri.tryParse(ref.read(appConfigProvider).supabaseUrl);
    final code = server == null
        ? null
        : await ref.read(setupStoreProvider).read(server);
    if (mounted) {
      setState(() {
        _setupCode = code;
        _loadingSetup = false;
      });
    }
  }

  Future<void> _loadTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      if (mounted) setState(() => _timezone = zone.identifier);
    } on Object catch (error, stackTrace) {
      // Keep the default: some platforms cannot tell the zone, and H1 still works.
      logError('Time zone unknown', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _submit() async {
    if (_busy || _loadingSetup || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    if (_setupCode != null) {
      await _loadSetup();
      if (!mounted) return;
      if (_setupCode == null) {
        setState(() => _busy = false);
        return;
      }
    }
    if (!mounted) return;
    final setupStore = ref.read(setupStoreProvider);
    final setupSignal = ref.read(serverSessionProvider).setupPending;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final repo = ref.read(householdOnboardingRepositoryProvider);
    final plan = ref.read(onboardingPlanProvider.notifier);

    setState(() => _busy = true);
    // Set before the call: the session refresh inside it may re-route before the reply.
    plan.start(seedExamples: _examples);
    setState(() => _creating = true);
    final result = await repo.create(
      householdName: _family.text,
      displayName: _name.text,
      colorHex: toHex(MemberPalette.swatches[_swatch].light),
      timezone: _timezone,
      locale: householdLocaleTag(locale),
      founderCode: _needsCode ? (_setupCode ?? _founderCode.text) : null,
      seedExamples: _examples,
      deviceLabel: deviceLabel(
        l10n: l10n,
        ownerName: _name.text,
        host: currentDeviceHost(),
      ),
    );
    if (mounted) setState(() => _creating = false);
    if (result is Ok) {
      await setupStore.clear();
      setupSignal.value = false;
    }
    if (result case Err(:final failure)
        when failure.code == 'founder_code_invalid' ||
            failure.code == 'founder_code_required') {
      await setupStore.clear();
      setupSignal.value = false;
      _setupCode = null;
    }
    if (!mounted) return;
    switch (result) {
      case Ok():
        // The router normally moves on once the session is Ready. If it does not, say so
        // and open the escapes after a while, instead of leaving the screen locked.
        _stallTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) setState(() => _stalled = true);
        });
        context.go(Routes.welcomeMembers);
      case Err(:final failure):
        plan.clear();
        setState(() => _busy = false);
        _showFailure(failure);
    }
  }

  void _showFailure(Failure failure) {
    final l10n = context.l10n;
    switch (failure.code) {
      case 'founder_code_required':
        setState(() => _codeError = l10n.householdNewErrNoCode);
      case 'founder_code_invalid':
        setState(() => _codeError = l10n.householdNewErrCodeWrong);
      case 'rate_limited':
        context.showMessage(l10n.householdNewErrRateLimited);
      default:
        context.showFailure(failure);
    }
  }

  Future<void> _signOut() async {
    await ref.read(setupStoreProvider).clear();
    if (mounted) ref.read(serverSessionProvider).setupPending.value = false;
    if (mounted) await ref.read(identityRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final locale = Localizations.localeOf(context);
    final language = switch (locale.languageCode) {
      'de' => l10n.householdLanguageDe,
      'en' => l10n.householdLanguageEn,
      'fr' => l10n.householdLanguageFr,
      'es' => l10n.householdLanguageEs,
      _ => l10n.householdLanguageDe,
    };

    return Scaffold(
      // The chosen colour shows as a tick in its swatch, under "Deine Farbe"; a dot in
      // the bar said nothing on its own.
      appBar: AppBar(title: Text(l10n.householdNewTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(Tokens.space6),
                children: [
                  TextFormField(
                    controller: _family,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n.householdNewFamilyName,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: Tokens.space4),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n.householdNewYourName,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    l10n.householdNewColour,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: Tokens.space2),
                  _SwatchGrid(
                    children: [
                      for (final (i, swatch) in MemberPalette.swatches.indexed)
                        _Swatch(
                          swatch: swatch,
                          label: l10n.householdNewColourOption('${i + 1}'),
                          selected: i == _swatch,
                          onTap: _busy
                              ? null
                              : () => setState(() => _swatch = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space3),
                  // One quiet line; the zone and language are changed in Settings later.
                  Text(
                    l10n.householdNewDefaults(
                      timezoneCity(_timezone),
                      language,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
                  ),
                  if (_needsCode && _setupCode != null)
                    Text(l10n.householdNewCodeSaved),
                  if (_needsCode && _setupCode == null && !_loadingSetup) ...[
                    const SizedBox(height: Tokens.space4),
                    TextFormField(
                      controller: _founderCode,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: l10n.householdNewFounderCode,
                        helperText: l10n.householdNewFounderHelp,
                        // The last sentence is the point (not the code from the
                        // sign-in mail): never cut it, even at 360 px.
                        helperMaxLines: 6,
                        errorText: _codeError,
                      ),
                      validator: _required,
                      onChanged: (_) {
                        if (_codeError != null) {
                          setState(() => _codeError = null);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: Tokens.space2),
                  CheckboxListTile(
                    value: _examples,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _examples = v ?? false),
                    title: Text(l10n.householdSeedExamples),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: Tokens.space4),
                  FilledButton(
                    key: const ValueKey('new-family-create'),
                    onPressed: _busy || _loadingSetup ? null : _submit,
                    child: _creating
                        ? BusyButtonLabel(label: l10n.householdNewCreating)
                        : Text(l10n.householdNewCreate),
                  ),
                  if (_stalled) ...[
                    const SizedBox(height: Tokens.space3),
                    Text(
                      l10n.householdNewStalled,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ww.ink2,
                      ),
                    ),
                  ],
                  const SizedBox(height: Tokens.space4),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(
                        // Locked while creating, open again once the session stalls.
                        onPressed: _busy && !_stalled
                            ? null
                            : () async {
                                await ref.read(setupStoreProvider).clear();
                                if (mounted) {
                                  ref
                                          .read(serverSessionProvider)
                                          .setupPending
                                          .value =
                                      false;
                                  this.context.go(Routes.inviteCode);
                                }
                              },
                        child: Text(l10n.householdNewInvited),
                      ),
                      // Never locked: a user must always be able to leave this screen.
                      TextButton(
                        onPressed: _signOut,
                        child: Text(l10n.householdNewSignOut),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty)
      ? context.l10n.fieldRequired
      : null;
}

/// The swatches in even rows: all in one row where they fit, otherwise half per row
/// (4 × 2), never seven and one left over.
class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = Tokens.space2;
      final n = children.length;
      double width(int perRow) => perRow * _Swatch.size + (perRow - 1) * gap;
      final perRow = width(n) <= constraints.maxWidth ? n : (n + 1) ~/ 2;
      // Aligned, so the list around it does not stretch the rows back to full width.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: width(perRow),
          child: Wrap(spacing: gap, runSpacing: gap, children: children),
        ),
      );
    },
  );
}

/// One colour of the member palette: a round, labelled choice; the chosen one carries a
/// tick as well as the ring, so the choice does not rest on the ring alone.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.swatch,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const size = 48.0;

  final MemberSwatch swatch;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: swatch.light,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 22,
                color: Theme.of(context).colorScheme.surface,
              )
            : null,
      ),
    ),
  );
}

/// A time zone as a person reads it: the city of an IANA name ("Europe/Berlin" →
/// "Berlin", "America/Argentina/Buenos_Aires" → "Buenos Aires"); anything else as it is.
String timezoneCity(String zone) {
  final city = zone.split('/').last.replaceAll('_', ' ').trim();
  return city.isEmpty ? zone : city;
}
