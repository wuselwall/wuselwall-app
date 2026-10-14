import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/baseline_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/feed_tokens_page.dart';
import 'package:wuselwall/features/home/ui/register_home_page.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/recipe_editor_page.dart';
import 'package:wuselwall/features/meals/ui/recipe_view_page.dart';
import 'package:wuselwall/features/meals/ui/recipes_page.dart';
import 'package:wuselwall/features/school/ui/school_setup_page.dart';
import 'package:wuselwall/features/school/ui/timetable_editor_page.dart';
import 'package:wuselwall/features/settings/ui/household_settings_page.dart';
import 'package:wuselwall/features/settings/ui/settings_page.dart';
import 'package:wuselwall/features/setup/ui/enrol_page.dart';
import 'package:wuselwall/features/setup/ui/mfa_challenge_page.dart';
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
  static const mfa = '/setup/mfa';
  static const register = '/setup/register';
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
  static const baselines = '/settings/baselines';

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
        Ready() =>
          (Routes.isSetup(path) || path == Routes.splash) ? Routes.home : null,
        // SignedOut, or an error on first load (the splash page shows it).
        _ =>
          session.hasError
              ? (path == Routes.splash ? null : Routes.splash)
              : (Routes.isSetup(path) &&
                        path != Routes.mfa &&
                        path != Routes.register
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
          GoRoute(path: 'sign-in', builder: (_, _) => const SignInPage()),
          GoRoute(path: 'enrol', builder: (_, _) => const EnrolPage()),
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
        path: Routes.home,
        builder: (_, _) => Consumer(
          builder: (_, ref, _) =>
              RegisterHomePage(register: ref.watch(uiRegisterProvider)),
        ),
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: Routes.householdSettings,
        builder: (_, _) => const HouseholdSettingsPage(),
      ),
      GoRoute(path: Routes.system, builder: (_, _) => const SystemPage()),
      GoRoute(
        path: Routes.feedTokens,
        builder: (_, _) => const FeedTokensPage(),
      ),
      GoRoute(path: Routes.baselines, builder: (_, _) => const BaselinePage()),
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
