import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/system_bars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// Prototype for issue #306: how the bar meets the page above it. The demo chooses it
/// with `?bar=fade` or `?bar=dock`; the app itself still draws the band.
enum PersonBarLook {
  /// A flat band in its own colour (today).
  band,

  /// The page's own colour, and the content fades out above it.
  fade,

  /// A rounded capsule that floats over the content.
  dock,
}

/// "Who am I right now?" — one avatar per household member on shared and kiosk
/// devices. Each is a colour *and* an initial, never colour alone (NFR-13). Personal
/// devices show nothing: their profile is fixed.
class ActingProfileBar extends ConsumerWidget {
  const ActingProfileBar({this.attached = false, this.fades = true, super.key});

  static PersonBarLook look = PersonBarLook.band;

  /// How far the fade reaches into the content above the bar.
  static const fadeExtent = 40.0;

  /// The room a scroll view leaves at its end so its last entry clears the dock.
  static double dockClearance(BuildContext context) =>
      look == PersonBarLook.dock ? 132 : 0;

  /// Under another bottom bar (the kid home's tabs): it continues that bar's colour
  /// whatever the look.
  final bool attached;

  /// False under a page that ends in its own action (the shopping list's button):
  /// nothing scrolls into the bar there, so nothing fades out above it.
  final bool fades;

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
    final look = attached ? PersonBarLook.band : ActingProfileBar.look;
    final scheme = Theme.of(context).colorScheme;
    // The page the bar sits on: the wall's detail and a home have different ones.
    final page = Material.maybeOf(context)?.color ?? scheme.surface;
    final color = look == PersonBarLook.fade ? page : scheme.surfaceContainer;

    Widget people(List<Member> list) => Row(
      mainAxisSize: MainAxisSize.min,
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
              nameWidth: narrow ? size + Tokens.space2 : size + Tokens.space6,
              selected: m.id == acting,
              onTap: () {
                // Another person: a guardian's PIN window ends with the switch
                // (specs/08, step-up on a shared device), on the server too.
                if (m.id != acting) {
                  guardianStepDown(ref);
                }
                ref.read(actingProfileProvider.notifier).select(m.id);
              },
            ),
          ),
      ],
    );
    final question = !narrow && acting == null;

    if (look == PersonBarLook.dock) {
      // The capsule is as wide as the family; a large one scrolls sideways inside it.
      return SystemBars(
        navigationColor: page,
        child: GuardianStepDownOnLeave(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space3,
                0,
                Tokens.space3,
                Tokens.space3,
              ),
              child: Center(
                heightFactor: 1,
                child: Material(
                  color: color,
                  elevation: 10,
                  shadowColor: Colors.black.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(36),
                    side: BorderSide(color: context.ww.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Tokens.space2,
                      horizontal: narrow ? Tokens.space2 : Tokens.space4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (question) ...[
                          Text(l10n.actingWho),
                          const SizedBox(width: Tokens.space3),
                        ],
                        Flexible(
                          child: members.when(
                            data: (list) => SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: people(list),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // The bar is on every home of a shared device and the wall, and stays mounted while
    // the settings are open above it: it ends a guardian's PIN window when they are left.
    final bar = SystemBars(
      navigationColor: color,
      child: GuardianStepDownOnLeave(
        child: Material(
          color: color,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Tokens.space2,
                horizontal: narrow ? Tokens.space2 : Tokens.space4,
              ),
              child: Row(
                children: [
                  if (question) ...[
                    Text(l10n.actingWho),
                    const SizedBox(width: Tokens.space3),
                  ],
                  Expanded(
                    child: members.when(
                      // One row, centred when it fits; a large family scrolls
                      // sideways instead of wrapping to a second row.
                      data: (list) => LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: Center(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: people(list),
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
        ),
      ),
    );
    if (look != PersonBarLook.fade || !fades) return bar;
    // The last of the content dissolves into the page just above the avatars. The
    // bar is the later child of its column, so this paints over the content's end.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -fadeExtent,
          height: fadeExtent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.35, 0.7, 1],
                  colors: [
                    page.withValues(alpha: 0),
                    page.withValues(alpha: 0.35),
                    page.withValues(alpha: 0.82),
                    page,
                  ],
                ),
              ),
            ),
          ),
        ),
        bar,
      ],
    );
  }
}

/// A page with the bar at its end: under it, or, as a dock, floating over it.
class WithActingProfileBar extends StatelessWidget {
  const WithActingProfileBar({
    required this.child,
    this.show = true,
    this.behind = true,
    super.key,
  });

  final Widget child;

  /// Whether the page runs on behind a dock. False for a page that ends in its own
  /// action (the shopping list's button): the dock sits under it instead.
  final bool behind;

  /// False where a page leaves the bar out for a while.
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    if (ActingProfileBar.look == PersonBarLook.dock) {
      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: behind ? 0 : ActingProfileBar.dockClearance(context),
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
    return Column(
      children: [
        Expanded(child: child),
        ActingProfileBar(fades: behind),
      ],
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
              height: MediaQuery.textScalerOf(context).scale(
                (Theme.of(context).textTheme.labelMedium?.fontSize ?? 12) * 1.5,
              ),
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
