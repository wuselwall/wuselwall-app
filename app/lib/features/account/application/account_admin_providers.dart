import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/account/data/account_admin_repository.dart';
import 'package:wuselwall/features/account/domain/member_security.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';

final accountAdminRepositoryProvider = Provider<AccountAdminRepository>(
  (ref) => AccountAdminRepository(
    ref.watch(apiClientProvider),
    ref.watch(supabaseClientProvider).auth,
  ),
);

/// Each adult's account and second-factor state, for the acting guardian. Only watched where
/// a guardian is looking (Mitglieder); invalidate after a reset.
final memberSecurityProvider = FutureProvider.autoDispose<List<MemberSecurity>>(
  (ref) async {
    final actor = ref.watch(actingProfileProvider);
    if (actor == null) return const [];
    return (await ref
            .watch(accountAdminRepositoryProvider)
            .memberSecurity(actor))
        .unwrap();
  },
);
