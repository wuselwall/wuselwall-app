import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/ui/settings_group_page.dart';

/// What a child, or an adult who is not a guardian, sees under Einstellungen on a family
/// tablet or the kitchen wall: their own page and nothing else (specs/09, "Settings on a
/// shared device"). It is the Personal group, narrowed by `SettingsEnv.ownOnly` to the
/// settings the server lets a member change for themselves, titled "Einstellungen" with
/// their name on a second line. Back leads home: there is no top page to return to.
class OwnSettingsPage extends ConsumerWidget {
  const OwnSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acting = ref.watch(actingProfileProvider);
    final name = ref
        .watch(membersProvider)
        .value
        ?.where((m) => m.id == acting)
        .firstOrNull
        ?.displayName;
    return SettingsGroupPage(
      group: SettingsGroup.personal,
      parentRoute: Routes.home,
      showViewSwitch: false,
      // "Einstellungen" with the name below: "Einstellungen für Emma" did not fit.
      title: context.l10n.settingsTitle,
      subtitle: name,
    );
  }
}
