import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';

/// Builds the [ThemeData] for a register and shade (specs/17, direction A
/// "Küchentisch"). Dark is not cosmetic: the kitchen is bright in the morning and dim
/// at night (specs/09); night is the kiosk's own third shade.
abstract final class AppTheme {
  static ThemeData build(UiRegister register, Shade shade) {
    final c = Palette.of(shade);
    final brightness = shade == Shade.light
        ? Brightness.light
        : Brightness.dark;

    // Explicit, not ColorScheme.fromSeed: the seed's tonal algorithm would not
    // reproduce the contrast-checked values in palette.dart.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandTint,
      onPrimaryContainer: c.onBrandTint,
      secondary: c.ink2,
      onSecondary: c.surface,
      secondaryContainer: c.sunken,
      onSecondaryContainer: c.ink,
      tertiary: Palette.points,
      onTertiary: Palette.onPoints,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.sunken,
      onErrorContainer: c.danger,
      // The page ground is paper; cards and sheets sit on it as `surface`.
      surface: c.bg,
      onSurface: c.ink,
      onSurfaceVariant: c.ink2,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.sunken,
      surfaceContainerHigh: c.sunken,
      surfaceContainerHighest: c.sunken,
      outline: c.ink3,
      outlineVariant: c.line,
      inverseSurface: c.ink,
      onInverseSurface: c.bg,
      inversePrimary: shade == Shade.light
          ? Palette.dark.brand
          : Palette.light.brand,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );

    final touch = register.touchTarget;
    final base = register.baseFontSize;
    final radius = BorderRadius.circular(register.radius);
    final shape = RoundedRectangleBorder(borderRadius: radius);

    // Material's default body size is 14; scale the whole text theme from there so
    // every style keeps its relative weight in the register.
    // `black`/`white` carry colour only; `englishLike` carries the sizes to scale.
    final typography = Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    );
    final textTheme =
        (brightness == Brightness.dark ? typography.white : typography.black)
            .merge(typography.englishLike)
            .apply(
              fontSizeFactor: base / 14,
              fontFamily: Tokens.fontUi,
              fontFamilyFallback: const ['NotoSansSymbols'],
              bodyColor: c.ink,
              displayColor: c.ink,
            );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.line,
      fontFamily: Tokens.fontUi,
      fontFamilyFallback: const ['NotoSansSymbols'],
      textTheme: textTheme,
      extensions: [WwColors(shade: shade)],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: register == UiRegister.adult
          ? VisualDensity.standard
          : VisualDensity.comfortable,
      // NFR-13 sets `touch` as the *actual* minimum hit edge, not a nominal size
      // to shrink from. `VisualDensity.comfortable` (kid/kiosk, above) subtracts
      // 4 logical px per axis from a button's layout size, so a nominal 56 button
      // rendered at 52 — under the minimum. Pin each button style's own density to
      // `standard` so `minimumSize` is the actual rendered size; the page-level
      // `comfortable` density still loosens everything else (lists, padding).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(touch, touch),
          shape: shape,
          visualDensity: VisualDensity.standard,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(touch, touch),
          shape: shape,
          visualDensity: VisualDensity.standard,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(touch, touch),
          visualDensity: VisualDensity.standard,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size(touch, touch),
          visualDensity: VisualDensity.standard,
        ),
      ),
      segmentedButtonTheme: _segmentedButtonTheme(
        scheme,
        textTheme.labelLarge!,
        touch,
        shape,
      ),
      chipTheme: _chipTheme(scheme),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
      ),
      // Borders separate; shadows are for sheets and dialogs only (specs/17).
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: touch + Tokens.space4,
        titleTextStyle: textTheme.titleLarge,
      ),
    );
  }

  /// A selected segment is `primaryContainer` with `onPrimaryContainer` text. Material
  /// 3 would paint it `secondaryContainer`, which this palette maps to `sunken`: a
  /// selected segment then sat on the page at 1.02-1.08 : 1 and could not be told from
  /// an unselected one (a 40 px pill with the check icon switched off in settings).
  /// Built from [scheme] so [forMember] can rebuild it with the member's colours.
  static SegmentedButtonThemeData _segmentedButtonTheme(
    ColorScheme scheme,
    TextStyle labelStyle,
    double touch,
    OutlinedBorder shape,
  ) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(touch, touch)),
        // Pinned like the button themes above, so the page-level `comfortable`
        // density (kid, kiosk) does not shave 4 px off.
        visualDensity: VisualDensity.standard,
        // SegmentedButton ignores `minimumSize` (it sizes its segments as
        // max(font size + vertical padding, 40)), so the register's touch target
        // (NFR-13) is reached by padding: the label centred in a `touch` tall segment.
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: 12,
            vertical: math.max(0, (touch - labelStyle.fontSize!) / 2),
          ),
        ),
        shape: WidgetStatePropertyAll(shape),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.12)
                : scheme.outline,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? scheme.primaryContainer
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          return states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurface;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurface;
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return on.withValues(alpha: 0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return on.withValues(alpha: 0.08);
          }
          return null;
        }),
        // Fill alone is a weak cue (brand-tint is 1.1-1.5 : 1 against the page), so
        // the selected label is also heavier: not colour alone.
        textStyle: WidgetStateProperty.resolveWith(
          (states) => labelStyle.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Selected `FilterChip` and `ChoiceChip` take the same fill as a selected segment;
  /// the label stays `onSecondaryContainer` (ink), which reads on the brand tint and on
  /// the member tints some chips set themselves.
  static ChipThemeData _chipTheme(ColorScheme scheme) => ChipThemeData(
    selectedColor: scheme.primaryContainer,
    checkmarkColor: scheme.onPrimaryContainer,
  );

  /// [base] with a member's colour as the accent. On shared and kiosk devices the
  /// whole interface takes the acting member's colour, so "who am I right now" is
  /// answerable from across the room (specs/08).
  static ThemeData forMember(ThemeData base, Color stored) {
    final m = base.extension<WwColors>()!.member(stored);
    final scheme = base.colorScheme.copyWith(
      primary: m.ink,
      onPrimary: m.onInk,
      primaryContainer: m.tint,
      onPrimaryContainer: base.colorScheme.onSurface,
    );
    // The selection themes captured the base scheme's colours; rebuild them so a
    // selected segment or chip takes the member's tint too.
    final segmentedStyle = base.segmentedButtonTheme.style!;
    final minimum = segmentedStyle.minimumSize!.resolve({})!;
    return base.copyWith(
      colorScheme: scheme,
      segmentedButtonTheme: _segmentedButtonTheme(
        scheme,
        base.textTheme.labelLarge!,
        minimum.height,
        segmentedStyle.shape!.resolve({})!,
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
      ),
    );
  }
}
