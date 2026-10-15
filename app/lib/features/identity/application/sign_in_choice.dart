import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set when a code sign-in has just created a new account: E3 ("how would you like to
/// sign in next time?") is owed before the household steps. The router keeps a new
/// account on E3 while it is set. In memory only: an app closed in between skips E3
/// (see `isFirstCodeSignIn`).
class SignInChoiceOwedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void owe() => state = true;

  void clear() => state = false;
}

final signInChoiceOwedProvider =
    NotifierProvider<SignInChoiceOwedNotifier, bool>(
      SignInChoiceOwedNotifier.new,
    );
