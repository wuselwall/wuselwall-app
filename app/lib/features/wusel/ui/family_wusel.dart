import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Wusel as this family sees it (specs/25): the tufts in the members' colours, the
/// acting member's tuft in front, their outfit, and as present as the settings say.
///
/// [quietAllowed] says whether this is a moment a quiet Wusel still shows up for: an
/// empty state or a special day. Elsewhere a quiet Wusel stays away.
class FamilyWusel extends ConsumerWidget {
  const FamilyWusel({
    this.pose = WuselPose.idle,
    this.size = 96,
    this.moment,
    this.outfit,
    this.quietAllowed = false,
    this.tappable = false,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(lighterDayProvider);
    if (day.wusel == WuselPresence.off) return const SizedBox.shrink();
    if (day.wusel == WuselPresence.quiet && !quietAllowed) {
      return const SizedBox.shrink();
    }
    return Wusel(
      colors: WuselColors.of(context.ww.shade, ref.watch(wuselTuftsProvider)),
      pose: pose,
      size: size,
      outfit: outfit ?? day.outfit,
      frontTuft: ref.watch(wuselFrontTuftProvider),
      moment: moment,
      onTap: tappable && day.wusel == WuselPresence.lively ? () {} : null,
      // Quiet is still: the pose's still look, no motion.
      still: day.wusel == WuselPresence.quiet,
      // The wall rests between moments (specs/25 "Power on the wall").
      restAfter: ref.watch(uiRegisterProvider) == UiRegister.kiosk
          ? wallRestAfter
          : null,
    );
  }

  /// How long the wall's Wusel keeps blinking after a moment.
  static const wallRestAfter = Duration(seconds: 60);
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
    final text = Text(
      widget.line,
      style: widget.style ?? Theme.of(context).textTheme.titleMedium,
    );
    // Without Wusel the line is still worth saying: plain text, no bubble.
    if (!present) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FamilyWusel(
          pose: widget.pose,
          size: widget.size,
          moment: widget.moment,
          outfit: widget.outfit,
          quietAllowed: widget.quietAllowed,
          tappable: widget.tappable,
        ),
        const SizedBox(width: Tokens.space2),
        Flexible(
          child: AnimatedSwitcher(
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
                          fill: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          border: ww.line,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
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
          ),
        ),
      ],
    );
  }
}

/// A rounded bubble with a small tail on the left, pointing at Wusel.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 8.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(tail, 0, size.width - tail, size.height),
      const Radius.circular(16),
    );
    final mid = size.height / 2;
    final path = Path()
      ..addRRect(body)
      ..moveTo(tail + 1, mid - 7)
      ..lineTo(0, mid)
      ..lineTo(tail + 1, mid + 7)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        Path.combine(
          PathOperation.union,
          Path()..addRRect(body),
          Path()
            ..moveTo(tail + 1, mid - 7)
            ..lineTo(0, mid)
            ..lineTo(tail + 1, mid + 7)
            ..close(),
        ),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill || old.border != border;
}
