import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/link_host.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';

export 'package:wuselwall/core/l10n/app_locale.dart' show supportedLocales;

const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class WuselWallApp extends ConsumerWidget {
  const WuselWallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = ref.watch(uiRegisterProvider);
    // The wall display switches to its night shade from 21:00 whatever the OS or the
    // device's appearance says; otherwise the appearance picks light or dark, by
    // default as the OS does.
    final night = register == UiRegister.kiosk && ref.watch(nightProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      routerConfig: ref.watch(routerProvider),
      // This installation's language; null lets Flutter pick from the device's.
      locale: ref.watch(appLanguageProvider).value,
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      theme: AppTheme.build(register, night ? Shade.night : Shade.light),
      darkTheme: AppTheme.build(register, night ? Shade.night : Shade.dark),
      themeMode: ref.watch(appearanceProvider).value ?? ThemeMode.system,
      builder: (context, child) {
        final app = LinkHost(
          child: _ReminderHost(child: _MemberAccent(child: child!)),
        );
        final banner = ref.watch(appBannerProvider);
        if (banner == null) return app;
        return Column(
          children: [
            banner(context),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: app,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// On shared and kiosk devices, the acting member's colour becomes the accent of the
/// whole interface (specs/08). Personal devices keep the brand accent.
class _MemberAccent extends ConsumerWidget {
  const _MemberAccent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).value;
    final acting = ref.watch(actingProfileProvider);
    if (device == null || !device.deviceClass.isTapToSwitch || acting == null) {
      return child;
    }
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final member = members.where((m) => m.id == acting).firstOrNull;
    if (member == null) return child;
    return Theme(
      data: AppTheme.forMember(Theme.of(context), member.color),
      child: child,
    );
  }
}

/// Keeps the phone's local reminders in step (features/reminders): reads the sync once
/// at start, and re-plans whenever the app comes back to the foreground, since the days
/// and the OS permission may have moved on while it was closed.
class _ReminderHost extends ConsumerStatefulWidget {
  const _ReminderHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<_ReminderHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref
      ..invalidate(reminderPlanProvider)
      ..invalidate(notificationPermissionProvider)
      ..invalidate(reminderCardProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderSyncProvider);
    return widget.child;
  }
}
