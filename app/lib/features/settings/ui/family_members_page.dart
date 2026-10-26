import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/account/ui/mfa_reset_button.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/identity/ui/member_circle.dart';
import 'package:wuselwall/features/invitations/ui/members_invitations.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';

/// Familie → Mitglieder: the people of the family, in the board's order. Add a person,
/// invite an adult, drag to reorder, tap a row for the member page. Every change is a
/// guardian action.
class FamilyMembersPage extends ConsumerWidget {
  const FamilyMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopScope<Object?>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.settingsFamily);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.settingsMembers),
          leading: BackButton(
            onPressed: () => context.go(Routes.settingsFamily),
          ),
          actions: [
            IconButton(
              key: const ValueKey('add-member'),
              tooltip: l10n.addMember,
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => _addMember(context, ref),
            ),
            const SettingsViewSwitch(),
          ],
        ),
        // One scrollable: the member rows are a sliver reorderable list, so dragging works
        // without a nested list of its own.
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space4,
                Tokens.space4,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.settingsMembersHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.all(Tokens.space4),
              sliver: _MembersList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final l10n = context.l10n;
    final name = await askText(
      context,
      title: l10n.addMember,
      label: l10n.memberName,
    );
    if (name == null || !context.mounted) return;

    final colors = [0xFFE57373, 0xFFFFB74D, 0xFF64B5F6, 0xFFBA68C8, 0xFF81C784];
    final taken = ref.read(membersProvider).value?.length ?? 0;
    final result = await ref
        .read(identityRepositoryProvider)
        .addMember(
          actor: ref.read(actingProfileProvider),
          name: name,
          colorHex: toHex(Color(colors[taken % colors.length])),
        );
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref
        ..invalidate(membersProvider)
        ..invalidate(allMembersProvider),
      err: context.showFailure,
    );
  }
}

/// The people of the family, in the board's order, each a row that opens the member
/// page. Guardians drag the handle to reorder; the server keeps the new order for every
/// screen. People who are no longer with the family sit at the end, greyed. A sliver, so
/// the settings page stays one scrollable.
class _MembersList extends ConsumerStatefulWidget {
  const _MembersList();

  @override
  ConsumerState<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends ConsumerState<_MembersList> {
  /// The order on screen while a drag's write is in flight.
  List<Member>? _dragged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = ref.watch(allMembersProvider);
    final acting = ref.watch(actingProfileProvider);
    final list = members.value;
    if (list == null) {
      return SliverToBoxAdapter(
        child: AsyncValueView<List<Member>>(
          value: members,
          onRetry: () => ref.invalidate(allMembersProvider),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }
    final active = _dragged ?? list.where((m) => m.active).toList();
    final retired = list.where((m) => !m.active).toList();
    final isGuardian = list.any((m) => m.id == acting && m.isGuardian);
    return SliverMainAxisGroup(
      slivers: [
        SliverReorderableList(
          key: const ValueKey('members-list'),
          itemCount: active.length,
          onReorderItem: (from, to) => _reorder(active, from, to),
          // The row in flight is drawn in the overlay: give it the Material its tile needs.
          proxyDecorator: (child, _, _) => Material(elevation: 2, child: child),
          itemBuilder: (context, i) {
            final m = active[i];
            return _MemberTile(
              key: ValueKey('member-${m.id}'),
              member: m,
              handle: isGuardian && active.length > 1
                  ? ReorderableDragStartListener(
                      index: i,
                      child: Tooltip(
                        message: l10n.memberReorderHandle,
                        child: const Padding(
                          padding: EdgeInsets.all(Tokens.space2),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    )
                  : null,
            );
          },
        ),
        SliverList.list(
          children: [
            for (final m in retired)
              _MemberTile(key: ValueKey('member-${m.id}'), member: m),
            const InviteAdultTile(),
          ],
        ),
      ],
    );
  }

  Future<void> _reorder(List<Member> current, int from, int to) async {
    final next = List.of(current);
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() => _dragged = next);
    if (!await ensureGuardian(context, ref) || !mounted) {
      setState(() => _dragged = null);
      return;
    }
    final result = await ref
        .read(identityRepositoryProvider)
        .reorderMembers(
          actor: ref.read(actingProfileProvider),
          profileIds: [for (final m in next) m.id],
        );
    if (!mounted) return;
    ref
      ..invalidate(allMembersProvider)
      ..invalidate(membersProvider);
    setState(() => _dragged = null);
    result.when(ok: (_) {}, err: context.showFailure);
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, this.handle, super.key});

  final Member member;
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = member.isGuardian ? l10n.roleGuardian : l10n.roleMember;
    return Column(
      children: [
        Semantics(
          container: true,
          child: ListTile(
            leading: Opacity(
              opacity: member.active ? 1 : 0.5,
              child: MemberCircle(member: member),
            ),
            title: Text(member.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.active
                      ? (member.isChild ? l10n.householdKindChild : role)
                      : l10n.memberInactive,
                ),
                MemberInvitationDetails(member: member),
              ],
            ),
            // The handle is the affordance when there is one: a chevron beside it would
            // squeeze the role into a sliver at phone width.
            trailing: handle ?? const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.member, extra: member.id),
          ),
        ),
        // Separate actions below the member link avoid nesting interactive nodes.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 72,
            end: Tokens.space4,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: Tokens.space1,
              children: [
                MfaResetButton(member: member),
                InviteMemberButton(member: member),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
