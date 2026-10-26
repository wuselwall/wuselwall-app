// Test-only entry states for real production screens. These select a destination
// directly; authentication, redirects and mutations are covered by journey tests.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/server/setup_link.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/calendar/application/external_calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/feed_repository.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/event_template_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/baseline_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/external_calendar_form_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/external_calendars_page.dart';
import 'package:wuselwall/features/calendar/ui/settings/feed_tokens_page.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/household/ui/deleted_family_page.dart';
import 'package:wuselwall/features/household/ui/members_page.dart';
import 'package:wuselwall/features/household/ui/new_family_page.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/ui/device_pair_page.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';
import 'package:wuselwall/features/invitations/ui/invite_code_page.dart';
import 'package:wuselwall/features/invitations/ui/invite_pending_page.dart';
import 'package:wuselwall/features/invitations/ui/join_invite_page.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/ui/recipe_editor_page.dart';
import 'package:wuselwall/features/meals/ui/recipe_view_page.dart';
import 'package:wuselwall/features/meals/ui/recipes_page.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';
import 'package:wuselwall/features/school/ui/school_setup_page.dart';
import 'package:wuselwall/features/school/ui/timetable_editor_page.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';
import 'package:wuselwall/features/settings/ui/family_members_page.dart';
import 'package:wuselwall/features/settings/ui/member_page.dart';
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

import 'inventory.g.dart';

/// A fake subscription contains no working capability or address.
class QualificationFeedRepository implements FeedRepository {
  final _tokens = <FeedToken>[
    FeedToken(
      id: 'qualification-feed',
      label: DemoData.tr4(
        'Kalender-App',
        'Calendar app',
        'Application calendrier',
        'Aplicación de calendario',
      ),
      filter: const FeedFilter(),
      createdAt: DateTime(2026, 10, 14),
      fetchCount: 0,
    ),
  ];
  @override
  Future<Result<List<FeedToken>>> tokens() async => Ok([..._tokens]);
  @override
  Future<Result<CreatedFeedToken>> create({
    required String? actor,
    required String label,
    required FeedFilter filter,
  }) async => const Ok(
    CreatedFeedToken(
      id: 'qualification-new-feed',
      token: 'qualification-not-a-valid-token',
    ),
  );
  @override
  Future<Result<void>> revoke({
    required String? actor,
    required String id,
  }) async {
    _tokens.removeWhere((token) => token.id == id);
    return const Ok(null);
  }
}

/// No secure-storage plugin, persisted installer capability or real server.
class QualificationSetupStore extends SetupStore {
  @override
  Future<String?> read(Uri server) async => null;
  @override
  Future<void> save(SetupLink link) async {}
  @override
  Future<void> clear() async {}
}

PendingInvitation get qualificationInvitation => PendingInvitation(
  id: 'qualification-invite',
  householdName: DemoData.tr4(
    'Familie Muster',
    'Example family',
    'Famille Exemple',
    'Familia Ejemplo',
  ),
  profileName: DemoData.members.first.displayName,
  inviterFirstName: DemoData.members[1].displayName,
  role: InvitationRole.guardian,
);

Account qualificationAccount({bool deleted = false}) => Account(
  userId: 'qualification-account',
  email: 'guardian@example.org',
  hasHousehold: false,
  creation: HouseholdCreation.code,
  fullName: 'Alex Example',
  givenName: 'Alex',
  pendingInvitations: [qualificationInvitation],
  deletedHousehold: deleted
      ? DeletedHousehold(
          id: 'qualification-family',
          name: qualificationInvitation.householdName,
          deletedAt: DateTime(2026, 10, 13),
          purgeAfter: DateTime(2026, 10, 27),
          canRestore: true,
        )
      : null,
);

/// Direct page composition is deliberately separate from production route guards.
/// Every destination still uses its real widgets, repositories, theme and semantics.
GoRouter qualificationFixtureRouter(String id) {
  final route = qualificationFixtureRoutes[id]!;
  return GoRouter(
    initialLocation: route,
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(path: route, builder: (_, _) => _fixturePage(id)),
      if (route != '/') GoRoute(path: '/', builder: (_, _) => _fixturePage(id)),
    ],
  );
}

Widget _fixturePage(String id) => id == 'pair'
    // The waiting screen contains a permanent spinner after its code is ready.
    // Freeze its tickers for repeatable captures without replacing the real UI.
    ? TickerMode(enabled: false, child: _Destination(id))
    : _Destination(id);

class _Destination extends ConsumerWidget {
  const _Destination(this.id);
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (id) {
    'setup' || 'setup-offline' => const SetupPage(),
    'wizard' => const WizardPage(),
    'sign-in' ||
    'sign-in-offline' => const SignInPage(initialEmail: 'guardian@example.org'),
    'password-sign-in' => const SignInPage(
      initialEmail: 'guardian@example.org',
    ),
    'password-reset' => const PasswordResetPage(
      initialEmail: 'guardian@example.org',
    ),
    'email-code' => const EmailCodePage(
      email: 'guardian@example.org',
      initialResendDelay: Duration.zero,
    ),
    'recipes-empty' || 'recipes-error' => const RecipesPage(),
    'sign-in-choice' => const SignInChoicePage(),
    'enrol' => const EnrolPage(),
    'pair' => const PairPage(),
    'first-run-wall' => const FirstRunPage(kind: FirstRun.kiosk),
    'first-run-kid' => const FirstRunPage(kind: FirstRun.kidWelcome),
    'device-pair' => const DevicePairPage(),
    'mfa' => const MfaChallengePage(),
    'register' => RegisterDevicePage(
      guardianName: DemoData.members.first.displayName,
    ),
    'new-family' => NewFamilyPage(account: qualificationAccount()),
    'deleted-family' => DeletedFamilyPage(
      account: qualificationAccount(deleted: true),
    ),
    'invite-pending' => const InvitePendingPage(),
    'join-invite' => JoinInvitePage(pending: qualificationInvitation),
    'invite-code' => const InviteCodePage(),
    'welcome-members' => const MembersPage(),
    'family-members' => const FamilyMembersPage(),
    'member-edit' => MemberPage(profileId: DemoData.papa),
    'shopping-list-edit' => const ShoppingListEditPage(listId: 'l-super'),
    'shopping-history' => const ShoppingHistoryPage(),
    'event-templates' => EventTemplatePage(
      args: EventEditArgs(date: DateTime(2026, 10, 14)),
    ),
    'event-create' => EventEditorPage(
      args: EventEditArgs(date: DateTime(2026, 10, 14)),
    ),
    'event-edit' => const EventEditorPage(
      args: EventEditArgs(eventId: 'e-turnen'),
    ),
    'recipe-create' => const RecipeEditorPage(),
    'recipe-edit' || 'recipe-view' => AsyncValueView(
      value: ref.watch(recipesProvider),
      data: (recipes) => id == 'recipe-edit'
          ? RecipeEditorPage(recipe: recipes.first)
          : RecipeViewPage(initial: recipes.first),
    ),
    'school-setup' => const SchoolSetupPage(),
    'timetable-edit' => AsyncValueView(
      value: ref.watch(schoolDataProvider),
      data: (data) => TimetableEditorPage(
        args: TimetableEditArgs(
          profileId: data.timetables.first.profileId,
          termId: data.timetables.first.termId,
        ),
      ),
    ),
    'timetable-import' => TimetableImportPage(
      args: TimetableImportArgs(
        profileId: DemoData.son,
        import: TimetableImport(
          classLabel: '4a',
          lessons: [
            for (var day = 1; day <= 5; day++)
              ImportLesson(
                weekday: day,
                period: 1,
                subject: DemoData.tr4('Ma', 'Math', 'Maths', 'Mat'),
                subjectName: DemoData.tr4(
                  'Mathematik',
                  'Mathematics',
                  'Mathématiques',
                  'Matemáticas',
                ),
              ),
          ],
        ),
      ),
    ),
    'feed-tokens' => const FeedTokensPage(),
    'external-calendars' ||
    'external-calendars-empty' => const ExternalCalendarsPage(),
    'external-calendar-create' => const ExternalCalendarFormPage(),
    'external-calendar-edit' => AsyncValueView(
      value: ref.watch(externalCalendarsProvider),
      data: (calendars) => ExternalCalendarFormPage(calendar: calendars.first),
    ),
    'usual-week' => const BaselinePage(),
    'shortcuts' => const ShortcutsPage(),
    'splash-error' => const SplashPage(),
    _ => throw StateError('Missing qualification fixture: $id'),
  };
}

const qualificationNetworkFailure = NetworkFailure();

AppConfig qualificationPasswordServerConfig() => AppConfig(
  environment: 'qualification',
  supabaseUrl: 'https://family.example.org',
  supabasePublishableKey: 'sb_publishable_qualification',
  server: ServerInfo(
    supabaseUrl: Uri.parse('https://family.example.org'),
    publishableKey: 'sb_publishable_qualification',
    apiVersion: 1,
    minAppVersion: '1.0.0',
    features: const [featurePasswordReset],
    emailCode: false,
  ),
);
