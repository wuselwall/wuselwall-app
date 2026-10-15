import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/baseline_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/external_calendar_form_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/external_calendars_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/feed_tokens_page.dart';
import 'package:wuselwall/features/home/ui/register_home_page.dart';
import 'package:wuselwall/features/household/application/household_providers.dart';
import 'package:wuselwall/features/household/ui/deleted_family_page.dart';
import 'package:wuselwall/features/household/ui/members_page.dart';
import 'package:wuselwall/features/household/ui/new_family_page.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/identity/ui/device_pair_page.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/recipe_editor_page.dart';
import 'package:wuselwall/features/meals/ui/recipe_view_page.dart';
import 'package:wuselwall/features/meals/ui/recipes_page.dart';
import 'package:wuselwall/features/reminders/ui/reminders_page.dart';
import 'package:wuselwall/features/school/ui/school_setup_page.dart';
import 'package:wuselwall/features/school/ui/timetable_editor_page.dart';
import 'package:wuselwall/features/settings/ui/household_settings_page.dart';
import 'package:wuselwall/features/settings/ui/settings_page.dart';
import 'package:wuselwall/features/setup/ui/enrol_page.dart';
import 'package:wuselwall/features/setup/ui/first_run_page.dart';
import 'package:wuselwall/features/setup/ui/mfa_challenge_page.dart';
import 'package:wuselwall/features/setup/ui/pair_page.dart';
import 'package:wuselwall/features/setup/ui/register_device_page.dart';
import 'package:wuselwall/features/setup/ui/setup_page.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';
import 'package:wuselwall/features/setup/ui/splash_page.dart';
import 'package:wuselwall/features/setup/ui/wizard_page.dart';
import 'package:wuselwall/features/shopping/ui/shopping_history_page.dart';
import 'package:wuselwall/features/system/ui/system_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const setup = '/setup';
  static const wizard = '/setup/household';
  static const signIn = '/setup/sign-in';
  static const enrol = '/setup/enrol';
  static const pair = '/setup/pair';
  static const firstRun = '/first-run';
  static const devicePair = '/settings/devices/pair';
  static const mfa = '/setup/mfa';
  static const register = '/setup/register';
  static const newFamily = '/setup/new-family';
  static const deletedFamily = '/setup/deleted-family';
  static const welcomeMembers = '/welcome/members';
  static const home = '/';
  static const settings = '/settings';
  static const householdSettings = '/settings/household';
  static const system = '/system';
  static const shoppingHistory = '/shopping/history';
  static const eventNew = '/calendar/new';
  static const eventEdit = '/calendar/edit';
  static const recipes = '/meals/recipes';
  static const recipeEdit = '/meals/recipes/edit';
  static const recipeView = '/meals/recipes/view';
  static const schoolSetup = '/school/setup';
  static const timetableEdit = '/school/timetable';
  static const feedTokens = '/settings/feeds';
  static const externalCalendars = '/settings/calendars';
  static const externalCalendarNew = '/settings/calendars/new';
  static const externalCalendarEdit = '/settings/calendars/edit';
  static const baselines = '/settings/baselines';
  static const reminders = '/settings/reminders';

  static bool isSetup(String path) =>
      path == setup || path.startsWith('$setup/');
}

/// One router; what it shows is decided by the device record behind the session:
/// not enrolled → setup screens, enrolled → home in the device's register.
final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects whenever the device (or its loading state) changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionStateProvider, (_, _) => refresh.value++)
    ..listen(pendingFirstRunProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final session = ref.read(sessionStateProvider);

      // First evaluation: wait, but never flash the setup screen.
      if (!session.hasValue && !session.hasError) {
        return path == Routes.splash ? null : Routes.splash;
      }

      // The System page is a developer tool and does not exist in release builds.
      if (path == Routes.system) return kDebugMode ? null : Routes.home;

      return switch (session.value) {
        NeedsMfa() => path == Routes.mfa ? null : Routes.mfa,
        NeedsRegistration() => path == Routes.register ? null : Routes.register,
        // A deleted family the account can restore or leave (specs/20 J6).
        NeedsHousehold(:final account) when account.deletedHousehold != null =>
          path == Routes.deletedFamily ? null : Routes.deletedFamily,
        NeedsHousehold() => path == Routes.newFamily ? null : Routes.newFamily,
        // A founder who has just created the household sees H2 once, before Today.
        Ready() when ref.read(onboardingPlanProvider) != null =>
          path == Routes.welcomeMembers ? null : Routes.welcomeMembers,
        Ready() => _readyRedirect(ref, path),
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
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: Routes.setup,
        builder: (_, _) => const SetupPage(),
        routes: [
          GoRoute(path: 'household', builder: (_, _) => const WizardPage()),
          GoRoute(
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
          GoRoute(
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
          GoRoute(path: 'sign-in', builder: (_, _) => const SignInPage()),
          GoRoute(path: 'enrol', builder: (_, _) => const EnrolPage()),
          GoRoute(path: 'pair', builder: (_, _) => const PairPage()),
          GoRoute(path: 'mfa', builder: (_, _) => const MfaChallengePage()),
          GoRoute(
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
      GoRoute(
        path: Routes.welcomeMembers,
        builder: (_, _) => const MembersPage(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) =>
              RegisterHomePage(register: ref.watch(uiRegisterProvider)),
        ),
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: Routes.devicePair,
        builder: (_, state) => DevicePairPage(
          initialKind: PairingKind.fromWire(state.uri.queryParameters['kind']),
        ),
      ),
      GoRoute(
        path: Routes.firstRun,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) {
            final kind = ref.watch(pendingFirstRunProvider).value;
            return kind == null ? const SplashPage() : FirstRunPage(kind: kind);
          },
        ),
      ),
      GoRoute(
        path: Routes.householdSettings,
        builder: (_, _) => const HouseholdSettingsPage(),
      ),
      GoRoute(path: Routes.system, builder: (_, _) => const SystemPage()),
      GoRoute(
        path: Routes.feedTokens,
        builder: (_, _) => const FeedTokensPage(),
      ),
      GoRoute(
        path: Routes.externalCalendars,
        builder: (_, _) => const ExternalCalendarsPage(),
      ),
      GoRoute(
        path: Routes.externalCalendarNew,
        builder: (_, _) => const ExternalCalendarFormPage(),
      ),
      GoRoute(
        path: Routes.externalCalendarEdit,
        builder: (_, state) => ExternalCalendarFormPage(
          calendar: state.extra as ExternalCalendar?,
        ),
      ),
      GoRoute(path: Routes.baselines, builder: (_, _) => const BaselinePage()),
      GoRoute(path: Routes.reminders, builder: (_, _) => const RemindersPage()),
      GoRoute(
        path: Routes.shoppingHistory,
        builder: (_, _) => const ShoppingHistoryPage(),
      ),
      GoRoute(
        path: Routes.eventNew,
        builder: (_, state) =>
            EventEditorPage(args: state.extra as EventEditArgs?),
      ),
      GoRoute(
        path: Routes.eventEdit,
        builder: (_, state) =>
            EventEditorPage(args: state.extra as EventEditArgs?),
      ),
      GoRoute(path: Routes.recipes, builder: (_, _) => const RecipesPage()),
      GoRoute(
        path: Routes.recipeEdit,
        builder: (_, state) => RecipeEditorPage(recipe: state.extra as Recipe?),
      ),
      GoRoute(
        path: Routes.recipeView,
        builder: (_, state) => RecipeViewPage(initial: state.extra! as Recipe),
      ),
      GoRoute(
        path: Routes.schoolSetup,
        builder: (_, state) => SchoolSetupPage(
          initialSchoolId: state.uri.queryParameters['school'],
        ),
      ),
      GoRoute(
        path: Routes.timetableEdit,
        builder: (_, state) =>
            TimetableEditorPage(args: state.extra as TimetableEditArgs?),
      ),
    ],
  );
});

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
