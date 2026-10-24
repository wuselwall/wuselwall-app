import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/ui/leave_family_tiles.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/settings/application/household_export_providers.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';

/// The family itself (specs/16 step 10.2): its name, and under Advanced the time zone,
/// the language of the wall, the data export and deletion. Guardian actions throughout.
class FamilyPage extends ConsumerStatefulWidget {
  const FamilyPage({super.key});

  @override
  ConsumerState<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends ConsumerState<FamilyPage> {
  final _name = TextEditingController();
  var _nameSeeded = false;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  IdentityRepository get _repo => ref.read(identityRepositoryProvider);

  Future<void> _update({String? name, String? timezone, String? locale}) async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    setState(() => _busy = true);
    final result = await _repo.updateHousehold(
      actor: ref.read(actingProfileProvider),
      name: name,
      timezone: timezone,
      locale: locale,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) {
        ref.invalidate(householdInfoProvider);
        context.showMessage(context.l10n.savedMessage);
      },
      err: context.showFailure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = ref.watch(householdInfoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.familyTitle),
        leading: BackButton(onPressed: () => context.go(Routes.settingsFamily)),
        actions: const [SettingsViewSwitch()],
      ),
      body: AsyncValueView<HouseholdInfo>(
        value: info,
        onRetry: () => ref.invalidate(householdInfoProvider),
        data: (household) {
          if (!_nameSeeded) {
            _name.text = household.name;
            _nameSeeded = true;
          }
          return _body(context, household);
        },
      ),
    );
  }

  Widget _body(BuildContext context, HouseholdInfo household) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final advanced = ref.watch(showAdvancedSettingsProvider);
    final nameChanged = _name.text.trim() != household.name;
    // Export and deletion: a guardian on their own phone (the server insists too).
    final acting = ref.watch(actingProfileProvider);
    final guardianOnPhone =
        ref.watch(deviceProvider).value?.deviceClass == DeviceClass.personal &&
        (ref.watch(membersProvider).value ?? const <Member>[]).any(
          (m) => m.id == acting && m.isGuardian,
        );
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        TextField(
          key: const ValueKey('family-name'),
          controller: _name,
          enabled: !_busy,
          maxLength: 60,
          decoration: InputDecoration(labelText: l10n.householdNewFamilyName),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveName(household),
        ),
        if (nameChanged)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('family-save-name'),
              onPressed: _busy ? null : () => _saveName(household),
              child: Text(l10n.save),
            ),
          ),
        if (advanced) ...[
          const SizedBox(height: Tokens.space4),
          ListTile(
            key: const ValueKey('family-timezone'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l10n.familyTimezone),
            subtitle: Text('${household.timezone}\n${l10n.familyTimezoneHelp}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _pickTimezone(household),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language),
            title: Text(l10n.familyLocale),
            subtitle: Text(l10n.familyLocaleHelp),
            trailing: DropdownButton<String>(
              key: const ValueKey('family-locale'),
              value: household.locale,
              items: [
                for (final (tag, label) in _locales(household.locale))
                  DropdownMenuItem(value: tag, child: Text(label)),
              ],
              onChanged: _busy
                  ? null
                  : (tag) {
                      if (tag != null && tag != household.locale) {
                        _update(locale: tag);
                      }
                    },
            ),
          ),
          if (guardianOnPhone) ...[
            const SizedBox(height: Tokens.space6),
            Text(l10n.exportFamilyTitle, style: theme.textTheme.titleMedium),
            const ExportFamilyTile(),
            const DeleteFamilyTile(),
          ],
        ] else
          const MoreSettingsHint(),
      ],
    );
  }

  /// The four app languages, plus the stored tag when it is none of them (a family that
  /// chose `de-CH`, say, keeps it in the list until it picks another).
  List<(String, String)> _locales(String current) {
    final known = [
      ('de-DE', 'Deutsch'),
      ('en-GB', 'English'),
      ('fr-FR', 'Français'),
      ('es-ES', 'Español'),
    ];
    if (known.any((k) => k.$1 == current)) return known;
    return [(current, current), ...known];
  }

  Future<void> _saveName(HouseholdInfo household) async {
    final name = _name.text.trim();
    if (name.isEmpty || name == household.name) return;
    await _update(name: name);
  }

  Future<void> _pickTimezone(HouseholdInfo household) async {
    final zone = await showDialog<String>(
      context: context,
      builder: (_) => _TimezoneDialog(current: household.timezone),
    );
    if (zone == null || zone == household.timezone || !mounted) return;
    await _update(timezone: zone);
  }
}

/// Every zone of the bundled database, narrowed by typing ("zurich", "berlin").
class _TimezoneDialog extends StatefulWidget {
  const _TimezoneDialog({required this.current});

  final String current;

  @override
  State<_TimezoneDialog> createState() => _TimezoneDialogState();
}

class _TimezoneDialogState extends State<_TimezoneDialog> {
  final _query = TextEditingController();
  late final List<String> _zones;

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    _zones =
        tz.timeZoneDatabase.locations.keys
            .where((z) => z.contains('/') && !z.startsWith('Etc/'))
            .toList()
          ..sort();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.text.trim().toLowerCase().replaceAll(' ', '_');
    final hits = q.isEmpty
        ? _zones
        : _zones.where((z) => z.toLowerCase().contains(q)).toList();
    return AlertDialog(
      title: Text(l10n.familyTimezone),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('timezone-search'),
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.familyTimezoneSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Tokens.space2),
            Expanded(
              child: ListView.builder(
                itemCount: hits.length,
                itemBuilder: (context, i) => ListTile(
                  key: ValueKey('timezone-${hits[i]}'),
                  dense: true,
                  title: Text(hits[i].replaceAll('_', ' ')),
                  selected: hits[i] == widget.current,
                  onTap: () => Navigator.pop(context, hits[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// "Daten exportieren". Only a guardian on their own phone sees it (GDPR Art. 20); the
/// server refuses everyone else too.
class ExportFamilyTile extends ConsumerStatefulWidget {
  const ExportFamilyTile({super.key});

  @override
  ConsumerState<ExportFamilyTile> createState() => _ExportFamilyTileState();
}

class _ExportFamilyTileState extends ConsumerState<ExportFamilyTile> {
  var _exporting = false;

  bool get _canExport {
    final device = ref.watch(deviceProvider).value;
    if (device?.deviceClass != DeviceClass.personal) return false;
    final acting = ref.watch(actingProfileProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return members.any((m) => m.id == acting && m.isGuardian);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canExport) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('export-data'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.download_outlined),
      title: Text(l10n.exportAction),
      subtitle: Text(l10n.exportExplanation),
      trailing: _exporting
          ? Semantics(
              label: l10n.exportInProgress,
              child: const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
      onTap: _exporting ? null : _export,
    );
  }

  Future<void> _export() async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    // Read before the first await: the share sheet is anchored to this tile on iPad.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final actor = ref.read(actingProfileProvider);

    setState(() => _exporting = true);
    try {
      final result = await ref
          .read(householdExportRepositoryProvider)
          .export(actor: actor);
      if (!mounted) return;
      switch (result) {
        case Err(:final failure):
          context.showFailure(failure);
        case Ok(:final value):
          final shared = await Result.guard(
            () => ref.read(shareExportProvider)(
              fileName: householdExportFileName(
                DateTime.now(),
                value.extension,
              ),
              bytes: value.bytes,
              mimeType: value.mimeType,
              origin: origin,
            ),
          );
          if (!mounted) return;
          shared.when(ok: (_) {}, err: context.showFailure);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
