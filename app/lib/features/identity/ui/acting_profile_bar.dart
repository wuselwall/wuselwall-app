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
    final width = MediaQuery.sizeOf(context).width;
    // On a phone the circles get smaller (never below the register's touch target)
    // and the question goes, so the family fits on one row.
    final narrow = width < 480;
    final target = ref.watch(uiRegisterProvider).touchTarget;
    final size = narrow ? target : target + 8;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: Tokens.space2,
            horizontal: narrow ? Tokens.space2 : Tokens.space4,
          ),
          child: Row(
            children: [
              if (!narrow && acting == null) ...[
                Text(l10n.actingWho),
                const SizedBox(width: Tokens.space3),
              ],
              Expanded(
                child: members.when(
                  // One row, centred when it fits; a large family scrolls
                  // sideways instead of wrapping to a second row.
                  data: (list) => LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final m in list.where((m) => m.active))
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: narrow ? 0 : Tokens.space2,
                                ),
                                child: _Avatar(
                                  member: m,
                                  size: size,
                                  nameWidth: narrow
                                      ? size + Tokens.space2
                                      : size + Tokens.space6,
                                  selected: m.id == acting,
                                  onTap: () => ref
                                      .read(actingProfileProvider.notifier)
                                      .select(m.id),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
    required this.nameWidth,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final double size;
  final double nameWidth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ww.member(member.color);
    // The name under the circle: two members may share an initial (Emma, Emil), and
    // children recognise their written name before they read anyone else's.
    return Semantics(
      button: true,
      focusable: true,
      onTap: onTap,
      selected: selected,
      label: member.displayName,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
            const SizedBox(height: Tokens.space1),
            // The whole name, never "Thom…": a long one shrinks to its box.
            SizedBox(
              width: nameWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  member.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: selected ? FontWeight.bold : null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reverts a kiosk to "nobody" after [timeout] without any touch (specs/08: 60 s).
/// Wrap the kiosk's home screen in it.
class IdleReverter extends ConsumerStatefulWidget {
  const IdleReverter({
    required this.child,
    this.timeout = const Duration(seconds: 60),
    this.onIdle,
    super.key,
  });

  final Widget child;
  final Duration timeout;

  /// Also called after the revert: state the screen resets itself, such as the board's
  /// "Alle Termine" switch.
  final VoidCallback? onIdle;

  @override
  ConsumerState<IdleReverter> createState() => _IdleReverterState();
}

class _IdleReverterState extends ConsumerState<IdleReverter> {
  Timer? _timer;

  void _touch() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
      if (!mounted) return;
      ref.read(actingProfileProvider.notifier).clear();
      widget.onIdle?.call();
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
