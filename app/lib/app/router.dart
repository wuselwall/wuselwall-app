import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/event_template_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/baseline_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/external_calendar_form_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/external_calendars_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/feed_tokens_page.dart';
import 'package:wuselwall/features/home/ui/register_home_page.dart';
import 'package:wuselwall/features/household/application/household_providers.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/household/ui/deleted_family_page.dart';
import 'package:wuselwall/features/household/ui/members_page.dart';
import 'package:wuselwall/features/household/ui/new_family_page.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/application/sign_in_choice.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/identity/ui/device_pair_page.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';
import 'package:wuselwall/features/invitations/ui/invite_code_page.dart';
import 'package:wuselwall/features/invitations/ui/invite_pending_page.dart';
import 'package:wuselwall/features/invitations/ui/join_invite_page.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/recipe_editor_page.dart';
import 'package:wuselwall/features/meals/ui/recipe_view_page.dart';
import 'package:wuselwall/features/meals/ui/recipes_page.dart';
import 'package:wuselwall/features/reminders/ui/reminders_page.dart';
import 'package:wuselwall/features/school/ui/school_setup_page.dart';
import 'package:wuselwall/features/school/ui/timetable_editor_page.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';
import 'package:wuselwall/features/settings/application/settings_access.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/ui/family_members_page.dart';
import 'package:wuselwall/features/settings/ui/family_page.dart';
import 'package:wuselwall/features/settings/ui/member_page.dart';
import 'package:wuselwall/features/settings/ui/own_settings_page.dart';
import 'package:wuselwall/features/settings/ui/settings_group_page.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';
import 'package:wuselwall/features/settings/ui/settings_page.dart';
import 'package:wuselwall/features/setup/ui/email_code_page.dart';
import 'package:wuselwall/features/setup/ui/enrol_page.dart';
import 'package:wuselwall/features/setup/ui/first_run_page.dart';
import 'package:wuselwall/features/setup/ui/mfa_challenge_page.dart';
import 'package:wuselwall/features/setup/ui/pair_page.dart';
import 'package:wuselwall/features/setup/ui/password_reset_page.dart';
import 'package:wuselwall/features/setup/ui/register_device_page.dart';
import 'package:wuselwall/features/setup/ui/setup_page.dart';
import 'package:wuselwall/features/setup/ui/sign_in_choice_page.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';
import 'package:wuselwall/features/setup/ui/splash_page.dart';
import 'package:wuselwall/features/setup/ui/wizard_page.dart';
import 'package:wuselwall/features/shopping/ui/shopping_history_page.dart';
import 'package:wuselwall/features/shopping/ui/shopping_list_edit_page.dart';
import 'package:wuselwall/features/shortcuts/ui/shortcuts_page.dart';
import 'package:wuselwall/features/system/ui/system_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const setup = '/setup';
  static const wizard = '/setup/household';
  static const signIn = '/setup/sign-in';
  static const emailCode = '/setup/email-code';
  static const signInChoice = '/setup/sign-in-choice';
  static const passwordReset = '/setup/password-reset';
  static const enrol = '/setup/enrol';
  static const pair = '/setup/pair';
  static const firstRun = '/first-run';
  static const devicePair = '/settings/devices/pair';
  static const mfa = '/setup/mfa';
  static const register = '/setup/register';
  static const newFamily = '/setup/new-family';
  static const deletedFamily = '/setup/deleted-family';
  static const invitePending = '/setup/invitations';
  static const joinInvite = '/setup/join';
  static const inviteCode = '/setup/invite';
  static const welcomeMembers = '/welcome/members';
  static const home = '/';
  static const settings = '/settings';

  /// The old one-page "Household settings" (before the groups): opens [settings].
  static const householdSettings = '/settings/household';

  // The groups of Einstellungen (specs/21), each its own page under /settings.
  static const settingsPersonal = '/settings/personal';
  static const settingsFamily = '/settings/family';
  static const settingsTasks = '/settings/tasks';
  static const settingsCalendar = '/settings/calendar-school';
  static const settingsMeals = '/settings/meals';
  static const settingsRituals = '/settings/rituals';
  static const settingsCelebrations = '/settings/celebrations';
  static const settingsKitchen = '/settings/kitchen-wall';
  static const settingsDevices = '/settings/devices';
  static const settingsAccount = '/settings/account';
  static const settingsServer = '/settings/server';
  static const settingsHelp = '/settings/help';

  // Pages inside a group.
  static const familyProfile = '/settings/family/profile';
  static const settingsMembers = '/settings/members';
  static const member = '/settings/member';
  static const shoppingListEdit = '/shopping/list';
  static const system = '/system';
  static const shoppingHistory = '/shopping/history';
  static const eventNew = '/calendar/new';
  static const eventEdit = '/calendar/edit';
  static const recipes = '/meals/recipes';
  static const recipeEdit = '/meals/recipes/edit';
  static const recipeView = '/meals/recipes/view';
  static const schoolSetup = '/school/setup';
  static const timetableEdit = '/school/timetable';
  static const timetableImport = '/school/import';
  static const feedTokens = '/settings/feeds';
  static const externalCalendars = '/settings/calendars';
  static const externalCalendarNew = '/settings/calendars/new';
  static const externalCalendarEdit = '/settings/calendars/edit';
  static const baselines = '/settings/baselines';
  static const reminders = '/settings/reminders';
  static const shortcuts = '/settings/shortcuts';

  static bool isSetup(String path) =>
      path == setup || path.startsWith('$setup/');
}

/// Einstellungen and every page below it.
bool isSettingsPath(String path) =>
    path == Routes.settings || path.startsWith('${Routes.settings}/');

/// Who may open which settings page (specs/09, "Settings on a shared device"). On a
/// personal phone, and for a guardian at a shared device or the wall, everything; with
/// nobody acting, nothing; for anyone else only their own page, at `/settings` or
/// `/settings/personal`. Null: the page stays.
String? settingsRedirect(SettingsAccess access, String path) {
  if (!isSettingsPath(path)) return null;
  return switch (access) {
    SettingsAccess.full => null,
    SettingsAccess.none => Routes.home,
    SettingsAccess.own =>
      path == Routes.settings || path == Routes.settingsPersonal
          ? null
          : Routes.settings,
  };
}

/// What every settings page stands in. The redirect of the router covers navigation with
/// `go`, but a page opened with `push` (the gear does) sits above the location the router
/// re-checks, so the page watches who is acting itself: when that person may no longer see
/// it (the wall's 60 s idle return, someone else tapping their avatar) it shows nothing and
/// moves on at once rather than leave stale content up. The wall also goes back to nobody
/// after 60 s without a touch, and the home board that counts that is not under a settings
/// page, so settings count it themselves.
class _SettingsScope extends ConsumerWidget {
  const _SettingsScope({required this.path, required this.child});

  final String path;
  final widgets.Widget child;

  @override
  widgets.Widget build(widgets.BuildContext context, WidgetRef ref) {
    final target = settingsRedirect(ref.watch(settingsAccessProvider), path);
    if (target != null) {
      widgets.WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(target);
      });
      return const widgets.SizedBox.shrink();
    }
    return ref.watch(deviceProvider).value?.deviceClass == DeviceClass.kiosk
        ? IdleReverter(child: child)
        : child;
  }
}

/// Builds a Flutter MaterialPage explicitly. GoRouter's default app-type
/// detection checks a separate MaterialApp package and misses WuselWall's
/// Flutter MaterialApp.router, otherwise disabling platform page transitions.
GoRoute _materialRoute({
  required String path,
  required widgets.Widget Function(widgets.BuildContext, GoRouterState) builder,
  List<RouteBase> routes = const [],
}) {
  final page = isSettingsPath(path)
      ? (widgets.BuildContext context, GoRouterState state) =>
            _SettingsScope(path: path, child: builder(context, state))
      : builder;
  return _plainRoute(path: path, builder: page, routes: routes);
}

GoRoute _plainRoute({
  required String path,
  required widgets.Widget Function(widgets.BuildContext, GoRouterState) builder,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) => flutter.MaterialPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    child: widgets.Builder(builder: (context) => builder(context, state)),
  ),
  routes: routes,
);

/// One router; what it shows is decided by the device record behind the session:
/// not enrolled → setup screens, enrolled → home in the device's register.
final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects whenever the device (or its loading state) changes.
  final refresh = ValueNotifier<int>(0);
  final setup = ref.read(serverSessionProvider).setupPending;
  void refreshSetup() => refresh.value++;
  setup.addListener(refreshSetup);
  ref.onDispose(() => setup.removeListener(refreshSetup));
  ref
    ..listen(sessionStateProvider, (_, _) => refresh.value++)
    ..listen(pendingFirstRunProvider, (_, _) => refresh.value++)
    ..listen(signInChoiceOwedProvider, (_, _) => refresh.value++)
    // Whoever acts decides what settings they may open; a change (the wall's idle
    // return, a switch to someone else) moves a settings page they may no longer see.
    ..listen(settingsAccessProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    overridePlatformDefaultLocation: setup.value,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final session = ref.read(sessionStateProvider);
      if (session.value is SignedOut &&
          setup.value &&
          (path == Routes.setup || path == Routes.splash)) {
        return Routes.signIn;
      }

      // First evaluation: wait, but never flash the setup screen.
      if (!session.hasValue && !session.hasError) {
        return path == Routes.splash ? null : Routes.splash;
      }

      // The one-page household settings became the groups of Einstellungen.
      if (path == Routes.householdSettings) return Routes.settings;

      // The System page is a developer tool and does not exist in release builds.
      if (path == Routes.system) return kDebugMode ? null : Routes.home;

      return switch (session.value) {
        NeedsMfa() => path == Routes.mfa ? null : Routes.mfa,
        NeedsRegistration() => path == Routes.register ? null : Routes.register,
        // A new account answers E3 once, before it starts or joins a family.
        NeedsHousehold() when ref.read(signInChoiceOwedProvider) =>
          path == Routes.signInChoice ? null : Routes.signInChoice,
        // A deleted family the account can restore or leave (specs/20 J6).
        NeedsHousehold(:final account) when account.deletedHousehold != null =>
          path == Routes.deletedFamily ? null : Routes.deletedFamily,
        NeedsHousehold(:final account, :final hasStoredInvite) =>
          _householdRedirect(path, account, hasStoredInvite, state.extra),
        // A founder who has just created the household sees H2 once, before Today.
        Ready() when ref.read(onboardingPlanProvider) != null =>
          path == Routes.welcomeMembers ? null : Routes.welcomeMembers,
        Ready() =>
          settingsRedirect(ref.read(settingsAccessProvider), path) ??
              _readyRedirect(ref, path),
        // SignedOut, or an error on first load (the splash page shows it).
        _ =>
          session.hasError
              ? (path == Routes.splash ? null : Routes.splash)
              : (Routes.isSetup(path) &&
                        path != Routes.mfa &&
                        path != Routes.register &&
                        path != Routes.newFamily
                    ? null
                    : Routes.setup),
      };
    },
    routes: [
      _materialRoute(
        path: Routes.splash,
        builder: (_, _) => const SplashPage(),
      ),
      _materialRoute(
        path: Routes.setup,
        builder: (_, _) => const SetupPage(),
        routes: [
          _materialRoute(
            path: 'household',
            builder: (_, _) => const WizardPage(),
          ),
          _materialRoute(
            path: 'invite',
            builder: (_, state) => InviteCodePage(
              initialSecret: state.extra is String
                  ? state.extra! as String
                  : null,
            ),
          ),
          _materialRoute(
            path: 'invitations',
            builder: (_, _) => const InvitePendingPage(),
          ),
          _materialRoute(
            path: 'join',
            builder: (_, state) => JoinInvitePage(
              pending: state.extra is PendingInvitation
                  ? state.extra! as PendingInvitation
                  : null,
            ),
          ),
          _materialRoute(
            path: 'new-family',
            builder: (_, _) => Consumer(
              builder: (_, ref, _) {
                final s = ref.watch(sessionStateProvider).value;
                return NewFamilyPage(
                  account: s is NeedsHousehold ? s.account : null,
                );
              },
            ),
          ),
          _materialRoute(
            path: 'sign-in',
            builder: (_, state) =>
                SignInPage(initialEmail: state.uri.queryParameters['email']),
          ),
          _materialRoute(
            path: 'email-code',
            builder: (_, state) =>
                EmailCodePage(email: state.uri.queryParameters['email'] ?? ''),
          ),
          _materialRoute(
            path: 'sign-in-choice',
            builder: (_, _) => const SignInChoicePage(),
          ),
          _materialRoute(
            path: 'password-reset',
            builder: (_, state) => PasswordResetPage(
              initialEmail: state.uri.queryParameters['email'],
            ),
          ),
          _materialRoute(
            path: 'deleted-family',
            builder: (_, _) => Consumer(
              builder: (_, ref, _) {
                final s = ref.watch(sessionStateProvider).value;
                return DeletedFamilyPage(
                  account: s is NeedsHousehold ? s.account : null,
                );
              },
            ),
          ),
          _materialRoute(path: 'enrol', builder: (_, _) => const EnrolPage()),
          _materialRoute(path: 'pair', builder: (_, _) => const PairPage()),
          _materialRoute(
            path: 'mfa',
            builder: (_, _) => const MfaChallengePage(),
          ),
          _materialRoute(
            path: 'register',
            builder: (_, _) => Consumer(
              builder: (_, ref, _) {
                final s = ref.watch(sessionStateProvider).value;
                return RegisterDevicePage(
                  guardianName: s is NeedsRegistration
                      ? s.guardian.displayName
                      : '',
                );
              },
            ),
          ),
        ],
      ),
      _materialRoute(
        path: Routes.welcomeMembers,
        builder: (_, _) => const MembersPage(),
      ),
      _materialRoute(
        path: Routes.home,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) =>
              RegisterHomePage(register: ref.watch(uiRegisterProvider)),
        ),
      ),
      _materialRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsPage(),
      ),
      _materialRoute(
        path: Routes.familyProfile,
        builder: (_, _) => const FamilyPage(),
      ),
      _materialRoute(
        path: Routes.settingsMembers,
        builder: (_, _) => const FamilyMembersPage(),
      ),
      for (final group in SettingsGroup.values)
        _materialRoute(
          path: group.route,
          builder: (_, _) => group == SettingsGroup.personal
              ? Consumer(
                  builder: (_, ref, _) =>
                      ref.watch(settingsAccessProvider) == SettingsAccess.own
                      ? const OwnSettingsPage()
                      : SettingsGroupPage(group: group),
                )
              : SettingsGroupPage(group: group),
        ),
      _materialRoute(
        path: Routes.member,
        builder: (_, state) => MemberPage(profileId: state.extra! as String),
      ),
      _materialRoute(
        path: Routes.shoppingListEdit,
        builder: (_, state) =>
            ShoppingListEditPage(listId: state.extra! as String),
      ),
      _materialRoute(
        path: Routes.devicePair,
        builder: (_, state) => DevicePairPage(
          initialKind: PairingKind.fromWire(state.uri.queryParameters['kind']),
          initialCode: state.extra is String ? state.extra! as String : null,
        ),
      ),
      _materialRoute(
        path: Routes.firstRun,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) {
            final kind = ref.watch(pendingFirstRunProvider).value;
            return kind == null ? const SplashPage() : FirstRunPage(kind: kind);
          },
        ),
      ),
      _materialRoute(
        path: Routes.system,
        builder: (_, _) => const SystemPage(),
      ),
      _materialRoute(
        path: Routes.feedTokens,
        builder: (_, _) => const FeedTokensPage(),
      ),
      _materialRoute(
        path: Routes.externalCalendars,
        builder: (_, _) => const ExternalCalendarsPage(),
      ),
      _materialRoute(
        path: Routes.externalCalendarNew,
        builder: (_, _) => const ExternalCalendarFormPage(),
      ),
      _materialRoute(
        path: Routes.externalCalendarEdit,
        builder: (_, state) => ExternalCalendarFormPage(
          calendar: state.extra as ExternalCalendar?,
        ),
      ),
      _materialRoute(
        path: Routes.baselines,
        builder: (_, _) => const BaselinePage(),
      ),
      _materialRoute(
        path: Routes.reminders,
        builder: (_, _) => const RemindersPage(),
      ),
      _materialRoute(
        path: Routes.shortcuts,
        builder: (_, _) => const ShortcutsPage(),
      ),
      _materialRoute(
        path: Routes.shoppingHistory,
        builder: (_, _) => const ShoppingHistoryPage(),
      ),
      // Neuer Termin starts on its tiles (specs/28); a tradition or a chosen template
      // goes straight to the editor.
      _materialRoute(
        path: Routes.eventNew,
        builder: (_, state) {
          final args = state.extra as EventEditArgs?;
          return args?.tradition != null || args?.template != null
              ? EventEditorPage(args: args)
              : EventTemplatePage(args: args);
        },
      ),
      _materialRoute(
        path: Routes.eventEdit,
        builder: (_, state) =>
            EventEditorPage(args: state.extra as EventEditArgs?),
      ),
      _materialRoute(
        path: Routes.recipes,
        builder: (_, _) => const RecipesPage(),
      ),
      _materialRoute(
        path: Routes.recipeEdit,
        builder: (_, state) => RecipeEditorPage(recipe: state.extra as Recipe?),
      ),
      _materialRoute(
        path: Routes.recipeView,
        builder: (_, state) => RecipeViewPage(initial: state.extra! as Recipe),
      ),
      _materialRoute(
        path: Routes.schoolSetup,
        builder: (_, state) => SchoolSetupPage(
          initialSchoolId: state.uri.queryParameters['school'],
        ),
      ),
      _materialRoute(
        path: Routes.timetableEdit,
        builder: (_, state) =>
            TimetableEditorPage(args: state.extra as TimetableEditArgs?),
      ),
      _materialRoute(
        path: Routes.timetableImport,
        builder: (_, state) =>
            TimetableImportPage(args: state.extra as TimetableImportArgs?),
      ),
    ],
  );
});

/// Where an account without a household belongs: the join confirmation of a kept invitation,
/// H0 when an invitation names its confirmed email, else H1. The code entry is open to it, as
/// is the join confirmation of a pending invitation the account chose on H0.
String? _householdRedirect(
  String path,
  Account account,
  bool storedInvite,
  Object? extra,
) {
  final target = storedInvite
      ? Routes.joinInvite
      : account.pendingInvitations.isNotEmpty
      ? Routes.invitePending
      : Routes.newFamily;
  final allowed = switch (path) {
    Routes.joinInvite => storedInvite || extra is PendingInvitation,
    Routes.inviteCode => true,
    Routes.invitePending || Routes.newFamily => !storedInvite,
    _ => false,
  };
  return allowed ? null : target;
}

/// Where an enrolled device goes from a setup screen or the splash: the introduction it owes
/// first, otherwise home. The pairing page stays up while the greeting is shown.
String? _readyRedirect(Ref ref, String path) {
  final owed = ref.read(pendingFirstRunProvider).value;
  if (owed != null) return path == Routes.firstRun ? null : Routes.firstRun;
  if (path == Routes.firstRun) return Routes.home;
  final greeting =
      path == Routes.pair && ref.read(pairingHandoffProvider) != null;
  return (Routes.isSetup(path) && !greeting) || path == Routes.splash
      ? Routes.home
      : null;
}
