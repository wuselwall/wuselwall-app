import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// "Who am I right now?" — one avatar per household member on shared and kiosk
/// devices. Each is a colour *and* an initial, never colour alone (NFR-13). Personal
/// devices show nothing: their profile is fixed.
class ActingProfileBar extends ConsumerWidget {
  const ActingProfileBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).value;
    if (device == null || !device.deviceClass.isTapToSwitch) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final members = ref.watch(membersProvider);
    final acting = ref.watch(actingProfileProvider);
    final size = ref.watch(uiRegisterProvider).touchTarget + 8;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Tokens.space2,
            horizontal: Tokens.space4,
          ),
          child: Row(
            children: [
              Text(acting == null ? l10n.actingWho : ''),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: members.when(
                  data: (list) => Wrap(
                    spacing: Tokens.space3,
                    children: [
                      for (final m in list.where((m) => m.active))
                        _Avatar(
                          member: m,
                          size: size,
                          selected: m.id == acting,
                          onTap: () => ref
                              .read(actingProfileProvider.notifier)
                              .select(m.id),
                        ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.member,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ww.member(member.color);
    return Semantics(
      button: true,
      selected: selected,
      label: member.displayName,
      child: InkResponse(
        onTap: onTap,
        child: Container(
          key: ValueKey('avatar-${member.id}'),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.ink,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 4,
            ),
          ),
          child: Text(
            member.initial,
            style: TextStyle(
              color: colors.onInk,
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reverts a kiosk to "nobody" after [timeout] without any touch (docs/08: 60 s).
/// Wrap the kiosk's home screen in it.
class IdleReverter extends ConsumerStatefulWidget {
  const IdleReverter({
    required this.child,
    this.timeout = const Duration(seconds: 60),
    super.key,
  });

  final Widget child;
  final Duration timeout;

  @override
  ConsumerState<IdleReverter> createState() => _IdleReverterState();
}

class _IdleReverterState extends ConsumerState<IdleReverter> {
  Timer? _timer;

  void _touch() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
      if (mounted) ref.read(actingProfileProvider.notifier).clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _touch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _touch(),
    child: widget.child,
  );
}
