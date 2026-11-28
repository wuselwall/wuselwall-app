import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// "Who am I right now?" on shared and kiosk devices (specs/09 "Who is here"). While
/// nobody is chosen it is a dock that floats over the end of the page: one avatar per
/// household member, each a colour *and* an initial, never colour alone (NFR-13). Once
/// someone is chosen the dock leaves the page to them, and a small button at the
/// bottom end says who is acting and lets them go. Personal devices show nothing:
/// their profile is fixed.
///
/// It floats, so a page places it with [WithActingProfileBar], never in a column.
class ActingProfileBar extends ConsumerWidget {
  const ActingProfileBar({super.key});

  static const _margin = Tokens.space3;

  static bool _narrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 480;

  /// On a phone the circles get smaller (never below the register's touch target),
  /// so the family fits on one row.
  static double _circle(BuildContext context, WidgetRef ref) {
    final target = ref.watch(uiRegisterProvider).touchTarget;
    return _narrow(context) ? target : target + 8;
  }

  /// The way out is never lower than 48 dp, whatever the register's touch target.
  static double _exitHeight(WidgetRef ref) =>
      ref.watch(uiRegisterProvider).touchTarget.clamp(48.0, double.infinity);

  static double _nameLine(BuildContext context) => MediaQuery.textScalerOf(
    context,
  ).scale((Theme.of(context).textTheme.labelMedium?.fontSize ?? 12) * 1.5);

  /// The room the bar covers at the end of a page: the dock while nobody is chosen,
  /// the button afterwards, nothing on a personal device. A page's own floating
  /// buttons sit above it by this much.
  static double extentOf(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).value;
    if (device == null || !device.deviceClass.isTapToSwitch) return 0;
    final inner = ref.watch(actingProfileProvider) == null
        ? Tokens.space3 * 2 +
              _circle(context, ref) +
              Tokens.space1 +
              _nameLine(context)
        : _exitHeight(ref);
    return inner + _margin * 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).value;
    if (device == null || !device.deviceClass.isTapToSwitch) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final members = [
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        if (m.active) m,
    ];
    final acting = ref.watch(actingProfileProvider);
    final narrow = _narrow(context);
    final size = _circle(context, ref);

    void leave() {
      // Nobody acts any more, so nobody is verified either (specs/08, step-up on a
      // shared device), on the server too.
      guardianStepDown(ref);
      ref.read(actingProfileProvider.notifier).clear();
    }

    final Widget shown;
    if (acting != null) {
      Member? who;
      for (final m in members) {
        if (m.id == acting) who = m;
      }
      shown = Align(
        key: const ValueKey('acting-exit-slot'),
        alignment: AlignmentDirectional.bottomEnd,
        heightFactor: 1,
        child: _ExitButton(member: who, height: _exitHeight(ref), onTap: leave),
      );
    } else if (members.isEmpty) {
      shown = const SizedBox.shrink(key: ValueKey('acting-nothing'));
    } else {
      shown = Align(
        key: const ValueKey('acting-dock-slot'),
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: _Soft(
          key: const ValueKey('acting-dock'),
          radius: 40,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: Tokens.space3,
              horizontal: narrow ? Tokens.space3 : Tokens.space6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!narrow) ...[
                  Text(l10n.actingWho),
                  const SizedBox(width: Tokens.space4),
                ],
                // As wide as the family; a large one scrolls sideways inside the
                // dock instead of wrapping to a second row.
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final m in members)
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
                              nameHeight: _nameLine(context),
                              onTap: () => ref
                                  .read(actingProfileProvider.notifier)
                                  .select(m.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // The bar is on every home of a shared device and the wall, and stays mounted while
    // the settings are open above it: it ends a guardian's PIN window when they are left.
    return GuardianStepDownOnLeave(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(_margin),
          // The dock sinks away and the button comes up; nothing moves where motion
          // is switched off (specs/26 "Motion").
          child: AnimatedSwitcher(
            duration: motionAllowed(context)
                ? Tokens.motionEmphasised
                : Duration.zero,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.bottomCenter,
              children: [...previous, ?current],
            ),
            child: shown,
          ),
        ),
      ),
    );
  }
}

/// A page with the bar floating over its end. The page learns the room the bar
/// covers as bottom padding of its [MediaQuery], the way it learns a gesture bar's:
/// a list that ends in that padding scrolls its last entry clear of the bar.
class WithActingProfileBar extends ConsumerWidget {
  const WithActingProfileBar({
    required this.child,
    this.show = true,
    super.key,
  });

  final Widget child;

  /// False where a page leaves the bar out for a while.
  final bool show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!show) return child;
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom:
                    media.padding.bottom +
                    ActingProfileBar.extentOf(context, ref),
              ),
            ),
            child: child,
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ActingProfileBar(),
        ),
      ],
    );
  }
}

/// The floating surface of the dock and the button: no outline, its edge fades into
/// the page, and a soft shadow lifts it (specs/17 "Who is here").
class _Soft extends StatelessWidget {
  const _Soft({required this.radius, required this.child, super.key});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.surfaceContainer;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: shape,
        boxShadow: [
          // The lift, wide and faint.
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
          // The edge: the surface's own colour, blurred outwards.
          BoxShadow(color: color, blurRadius: 14, spreadRadius: 3),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Who is acting, and the way out: their avatar, their name and a door. Tapping it
/// gives the device back to nobody, which the kiosk also does by itself after a
/// minute without a touch ([IdleReverter]).
class _ExitButton extends StatelessWidget {
  const _ExitButton({
    required this.member,
    required this.height,
    required this.onTap,
  });

  /// Null when the acting profile is no longer a member: the door still works.
  final Member? member;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = this.member;
    final circle = height - Tokens.space3;
    return Semantics(
      button: true,
      focusable: true,
      onTap: onTap,
      label: context.l10n.actingDone(member?.displayName ?? ''),
      excludeSemantics: true,
      child: _Soft(
        radius: height,
        child: InkWell(
          key: const ValueKey('acting-exit'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, maxWidth: 280),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Tokens.space2,
                end: Tokens.space4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (member != null) ...[
                    Container(
                      width: circle,
                      height: circle,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.ww.member(member.color).ink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        member.initial,
                        // A fixed circle keeps its letter's size (see MemberAvatar).
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: context.ww.member(member.color).onInk,
                          fontSize: circle * 0.45,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    Flexible(
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: Tokens.space2),
                  Icon(Icons.logout, color: theme.colorScheme.onSurface),
                ],
              ),
            ),
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
    required this.nameHeight,
    required this.onTap,
  });

  final Member member;
  final double size;
  final double nameWidth;
  final double nameHeight;
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
              ),
              child: Text(
                member.initial,
                // A fixed circle keeps its letter's size (see MemberAvatar).
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: colors.onInk,
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: Tokens.space1),
            // The whole name, never "Thom…": a long one shrinks to its box, and
            // every box has one line's height, so all names sit on one line.
            SizedBox(
              width: nameWidth,
              height: nameHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  member.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium,
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
      // Nobody acts any more, so nobody is verified either: the server forgets the
      // PIN window with the client (specs/08, step-up on the wall).
      guardianStepDown(ref);
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
