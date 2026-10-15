import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';

/// The signed-in account as `api.my_account()` reports it, for Settings (the leave action's
/// state and the family's name). Invalidate after a leave, a deletion or a restore.
final myAccountProvider = FutureProvider<Account>(
  (ref) => ref
      .watch(householdOnboardingRepositoryProvider)
      .account()
      .then((r) => r.unwrap()),
);
