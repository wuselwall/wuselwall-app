import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';

/// Set while a founder owes H2: from the start of H1's submit until H2 is done. The router
/// keeps a Ready session on H2 while it is set, so the session refresh that follows
/// household creation does not skip it. In memory only: an app closed in between simply
/// opens Today.
class OnboardingPlanNotifier extends Notifier<OnboardingPlan?> {
  @override
  OnboardingPlan? build() => null;

  void start({required bool seedExamples}) =>
      state = OnboardingPlan(seedExamples: seedExamples);

  void clear() => state = null;
}

final onboardingPlanProvider =
    NotifierProvider<OnboardingPlanNotifier, OnboardingPlan?>(
      OnboardingPlanNotifier.new,
    );
