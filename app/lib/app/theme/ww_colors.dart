import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/palette.dart';

/// What [ColorScheme] has no slot for: secondary inks, member colours, paper tints,
/// points gold. Read it with `context.ww`.
@immutable
class WwColors extends ThemeExtension<WwColors> {
  const WwColors({required this.shade});

  final Shade shade;

  ShadeColors get _c => Palette.of(shade);

  Color get sunken => _c.sunken;
  Color get line => _c.line;
  Color get ink2 => _c.ink2;
  Color get ink3 => _c.ink3;
  Color get success => _c.brand;
  Color get successContainer => _c.brandTint;
  Color get warning => _c.warning;
  Color get warningContainer => _c.warningContainer;
  Color get onWarningContainer => _c.onWarningContainer;
  Color get points => Palette.points;
  Color get onPoints => Palette.onPoints;

  /// A QR code's modules and ground: the shade's own text pair, darker side as ink,
  /// because scanners need dark on light. Paper, not white, in dark and night, so the
  /// code does not glare (night stays at its ~10:1).
  Color get qrInk => shade == Shade.light ? _c.ink : _c.bg;
  Color get qrPaper => shade == Shade.light ? _c.surface : _c.ink;
  ProviderButtonColors get appleButton => ProviderBrand.apple(shade);
  ProviderButtonColors get googleButton => ProviderBrand.google(shade);

  /// A member's colours for this shade, from their stored `colour_hex`.
  MemberColors member(Color stored) {
    final s = MemberPalette.resolve(stored);
    return MemberColors(
      ink: s.ink(shade),
      onInk: s.onInk(shade),
      tint: s.tint(shade),
    );
  }

  Color paper(PaperTint tint) => tint.of(shade);

  @override
  WwColors copyWith({Shade? shade}) => WwColors(shade: shade ?? this.shade);

  // Shades switch, they do not blend.
  @override
  WwColors lerp(WwColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

@immutable
class MemberColors {
  const MemberColors({
    required this.ink,
    required this.onInk,
    required this.tint,
  });

  /// Bands, dots, avatars and the accent while this member is acting.
  final Color ink;

  /// Text and icons on a filled [ink].
  final Color onInk;

  /// Quiet ground behind this member's things; text on it is [ink] or the shade's ink.
  final Color tint;
}

extension WwColorsContext on BuildContext {
  WwColors get ww => Theme.of(this).extension<WwColors>()!;
}
