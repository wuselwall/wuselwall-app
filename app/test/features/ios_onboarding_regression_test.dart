import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/setup/ui/setup_page.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';

import '../support/fakes.dart';

const _phone = Size(390, 844);

void main() {
  for (final locale in const [
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('es'),
  ]) {
    testWidgets(
      'iOS ${locale.languageCode} rejects blank and malformed email locally',
      (t) async {
        final identity = FakeIdentityRepository();
        final container = await pumpApp(
          t,
          locale: locale,
          size: _phone,
          overrides: baseOverrides(identity: identity, signedIn: false),
        );
        container.read(routerProvider).go(Routes.signIn);
        await t.pumpAndSettle();

        final page = find.byType(SignInPage);
        final l10n = t.element(page).l10n;
        expect(Theme.of(t.element(page)).platform, TargetPlatform.iOS);

        await t.tap(find.byType(FilledButton));
        await t.pumpAndSettle();
        expect(find.text(l10n.emailRequired), findsOneWidget);
        expect(identity.codeRequests, isEmpty);
        expect(identity.signIns, isEmpty);

        await t.enterText(find.byType(TextFormField).first, 'bad-address');
        await t.tap(find.byType(FilledButton));
        await t.pumpAndSettle();
        expect(find.text(l10n.emailInvalid), findsOneWidget);
        expect(identity.codeRequests, isEmpty);
        expect(identity.signIns, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets('iOS email-code fallback works after blank password validation', (
    t,
  ) async {
    final identity = FakeIdentityRepository();
    final container = await pumpApp(
      t,
      locale: const Locale('en'),
      size: _phone,
      overrides: baseOverrides(identity: identity, signedIn: false),
    );
    final router = container.read(routerProvider);
    router.go(Routes.signIn);
    await t.pumpAndSettle();
    final page = find.byType(SignInPage);
    final l10n = t.element(page).l10n;
    expect(Theme.of(t.element(page)).platform, TargetPlatform.iOS);

    await t.enterText(find.byType(TextFormField).first, 'ios@example.org');
    await t.tap(find.text(l10n.emailHavePassword));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.signInAction));
    await t.pumpAndSettle();
    expect(find.text(l10n.passwordRequired), findsOneWidget);

    await t.tap(find.text(l10n.emailUseCodeInstead));
    await t.pumpAndSettle();
    expect(identity.signIns, isEmpty);
    expect(identity.codeRequests, ['ios@example.org']);
    expect(find.text(l10n.emailCodeTitle), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'iOS keyboard submissions do not duplicate an in-flight email request',
    (t) async {
      final identity = _DelayedEmailIdentity();
      final container = await pumpApp(
        t,
        locale: const Locale('en'),
        size: _phone,
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(SignInPage))).platform,
        TargetPlatform.iOS,
      );

      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pump();
      await t.enterText(find.byType(TextFormField).first, 'ios@example.org');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pump();
      expect(find.text('Sending code…'), findsOneWidget);

      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pump();
      expect(identity.codeRequests, ['ios@example.org']);

      identity.complete.complete(const Ok(null));
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS offline welcome is accessible and clears when connectivity returns',
    (t) async {
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      final overrides = baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
      )..removeWhere((override) => override.origin == connectivityProvider);
      overrides.add(
        connectivityProvider.overrideWith((ref) async* {
          yield false;
          yield* connectivity.stream;
        }),
      );
      final container = await pumpApp(
        t,
        locale: const Locale('en'),
        size: _phone,
        overrides: overrides,
      );
      container.read(routerProvider).go(Routes.setup);
      await t.pumpAndSettle();
      final page = find.byType(SetupPage);
      final l10n = t.element(page).l10n;
      expect(Theme.of(t.element(page)).platform, TargetPlatform.iOS);
      expect(find.text(l10n.setupOfflineWelcome), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.container &&
              widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        t
            .widget<ButtonStyleButton>(find.byKey(const ValueKey('door-email')))
            .onPressed,
        isNull,
      );

      connectivity.add(true);
      await t.pumpAndSettle();
      expect(find.text(l10n.setupOfflineWelcome), findsNothing);
      expect(
        t
            .widget<ButtonStyleButton>(find.byKey(const ValueKey('door-email')))
            .onPressed,
        isNotNull,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _DelayedEmailIdentity extends FakeIdentityRepository {
  final complete = Completer<Result<void>>();

  @override
  Future<Result<void>> sendEmailCode(String email, {required String locale}) {
    codeRequests.add(email);
    return complete.future;
  }
}
