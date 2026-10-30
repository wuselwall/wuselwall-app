import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/whole_words_text.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/core/wusel/wusel_stage.dart';
import 'package:wuselwall/core/wusel/wusel_tilt.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Wusel as this family sees it (specs/25): the tufts in the members' colours, the
/// acting member's tuft in front, their outfit, and as present as the settings say.
///
/// [quietAllowed] says whether this is a moment a quiet Wusel still shows up for: an
/// empty state or a special day. Elsewhere a quiet Wusel stays away.
///
/// [home] makes this the screen's home for Wusel on the move (specs/25): a lively
/// Wusel in the kid register or on the wall travels from here and comes back, its
/// eyes follow the finger after a moment, and in the kid register it glances about
/// in the afterglow and leans with the tablet. [enter] lets it hop in from the lower
/// edge when the home appears.
class FamilyWusel extends ConsumerWidget {
  const FamilyWusel({
    this.pose = WuselPose.idle,
    this.size = 96,
    this.moment,
    this.outfit,
    this.quietAllowed = false,
    this.tappable = false,
    this.home = false,
    this.enter = false,
    super.key,
  });

  final WuselPose pose;
  final double size;
  final Object? moment;

  /// An occasion's outfit (the Partyhut on a birthday), over the member's own.
  final WuselOutfit? outfit;
  final bool quietAllowed;

  /// The kid register's small tap reactions.
  final bool tappable;

  final bool home;
  final bool enter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(lighterDayProvider);
    if (day.wusel == WuselPresence.off) return const SizedBox.shrink();
    if (day.wusel == WuselPresence.quiet && !quietAllowed) {
      return const SizedBox.shrink();
    }
    final register = ref.watch(uiRegisterProvider);
    final lively = day.wusel == WuselPresence.lively;
    // Wusel lives on the stage only in the kid register and on the wall, and only
    // lively (specs/25 "Wusel on the move").
    final stage = home && lively && register != UiRegister.adult
        ? WuselStage.maybeOf(context)
        : null;
    final kid = register == UiRegister.kid;
    final appearance = WuselAppearance(
      colors: WuselColors.of(context.ww.shade, ref.watch(wuselTuftsProvider)),
      outfit: outfit ?? day.outfit,
      frontTuft: ref.watch(wuselFrontTuftProvider),
    );
    final wusel = Wusel(
      colors: appearance.colors,
      pose: pose,
      size: size,
      outfit: appearance.outfit,
      frontTuft: appearance.frontTuft,
      moment: moment,
      onTap: tappable && lively
          ? () {
              // A tap is a moment: in the kid register the afterglow, on the wall
              // only the eyes on the finger, and Wusel stays in its corner.
              if (kid) {
                stage?.moment();
              } else {
                stage?.followFinger(wallFollowFor);
              }
            }
          : null,
      // Quiet is still: the pose's still look, no motion.
      still: day.wusel == WuselPresence.quiet,
      // The wall rests between moments (specs/25 "Power on the wall").
      restAfter: register == UiRegister.kiosk ? wallRestAfter : null,
      gazeAt: stage?.finger,
      glancing: kid ? stage?.afterglow : null,
      tilt: kid && stage != null && WuselTilt.available
          ? WuselTilt.instance
          : null,
    );
    if (stage == null) return wusel;
    return WuselHome(
      appearance: appearance,
      size: size,
      travels: pose != WuselPose.sleep && pose != WuselPose.think,
      afterglow: kid,
      enter: enter,
      child: wusel,
    );
  }

  /// How long the wall's Wusel keeps blinking after a moment.
  static const wallRestAfter = Duration(seconds: 60);

  /// How long the wall's Wusel follows the finger after a tap.
  static const wallFollowFor = Duration(seconds: 6);
}

/// Wusel with a line in a speech bubble beside it. The line is ordinary text in the
/// screen's reading order; the drawing is decoration. A tap on the bubble hides the
/// line for this moment (specs/25 "Where Wusel appears").
class WuselSays extends ConsumerStatefulWidget {
  const WuselSays({
    required this.line,
    this.pose = WuselPose.idle,
    this.size = 96,
    this.moment,
    this.outfit,
    this.quietAllowed = false,
    this.style,
    this.tappable = false,
    this.home = false,
    this.enter = false,
    this.stacked = false,
    this.trailing,
    super.key,
  });

  final String line;
  final WuselPose pose;
  final double size;
  final Object? moment;
  final WuselOutfit? outfit;
  final bool quietAllowed;
  final TextStyle? style;
  final bool tappable;

  /// See [FamilyWusel.home] and [FamilyWusel.enter].
  final bool home;
  final bool enter;

  /// On a phone: Wusel (with [trailing] at the row's end) above a bubble that has
  /// the full width, rather than a bubble squeezed beside Wusel.
  final bool stacked;

  /// Shown at the end of Wusel's row when [stacked] (the points pill).
  final Widget? trailing;

  @override
  ConsumerState<WuselSays> createState() => _WuselSaysState();
}

class _WuselSaysState extends ConsumerState<WuselSays> {
  bool _hidden = false;

  @override
  void didUpdateWidget(WuselSays old) {
    super.didUpdateWidget(old);
    if (old.moment != widget.moment || old.line != widget.line) {
      _hidden = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(lighterDayProvider);
    final present =
        day.wusel == WuselPresence.lively ||
        (day.wusel == WuselPresence.quiet && widget.quietAllowed);
    final ww = context.ww;
    final text = WholeWordsText(
      widget.line,
      style: widget.style ?? Theme.of(context).textTheme.titleMedium,
    );
    // Without Wusel the line is still worth saying: plain text, no bubble.
    if (!present) return text;
    final wusel = FamilyWusel(
      pose: widget.pose,
      size: widget.size,
      moment: widget.moment,
      outfit: widget.outfit,
      quietAllowed: widget.quietAllowed,
      tappable: widget.tappable,
      home: widget.home,
      enter: widget.enter,
    );
    final bubble = AnimatedSwitcher(
      duration: Tokens.motionStandard,
      child: _hidden
          ? const SizedBox.shrink()
          : Semantics(
              // The line is read; tapping hides it, which the hint says.
              onTapHint: context.l10n.wuselHideLine,
              child: GestureDetector(
                onTap: () => setState(() => _hidden = true),
                child: CustomPaint(
                  painter: _BubblePainter(
                    fill: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: ww.line,
                    tailUp: widget.stacked,
                    tailAt: widget.size / 2,
                  ),
                  child: Padding(
                    padding: widget.stacked
                        ? const EdgeInsets.fromLTRB(
                            Tokens.space4,
                            Tokens.space3 + 8,
                            Tokens.space4,
                            Tokens.space3,
                          )
                        : const EdgeInsets.fromLTRB(
                            Tokens.space4 + 8,
                            Tokens.space3,
                            Tokens.space4,
                            Tokens.space3,
                          ),
                    child: text,
                  ),
                ),
              ),
            ),
    );
    if (widget.stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [wusel, const Spacer(), ?widget.trailing]),
          const SizedBox(height: Tokens.space1),
          bubble,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        wusel,
        const SizedBox(width: Tokens.space2),
        Flexible(child: bubble),
      ],
    );
  }
}

/// A rounded bubble with a small tail pointing at Wusel: on the left, or with
/// [tailUp] on the top edge [tailAt] from the left (Wusel above the bubble).
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.fill,
    required this.border,
    this.tailUp = false,
    this.tailAt = 0,
  });

  final Color fill;
  final Color border;
  final bool tailUp;
  final double tailAt;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 8.0;
    final RRect body;
    final Path tip;
    if (tailUp) {
      body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, tail, size.width, size.height - tail),
        const Radius.circular(16),
      );
      final x = tailAt.clamp(24.0, size.width - 24);
      tip = Path()
        ..moveTo(x - 7, tail + 1)
        ..lineTo(x, 0)
        ..lineTo(x + 7, tail + 1)
        ..close();
    } else {
      body = RRect.fromRectAndRadius(
        Rect.fromLTWH(tail, 0, size.width - tail, size.height),
        const Radius.circular(16),
      );
      final mid = size.height / 2;
      tip = Path()
        ..moveTo(tail + 1, mid - 7)
        ..lineTo(0, mid)
        ..lineTo(tail + 1, mid + 7)
        ..close();
    }
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      tip,
    );
    canvas
      ..drawPath(shape, Paint()..color = fill)
      ..drawPath(
        shape,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill ||
      old.border != border ||
      old.tailUp != tailUp ||
      old.tailAt != tailAt;
}
