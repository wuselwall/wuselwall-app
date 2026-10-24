import 'package:flutter/material.dart';

/// Colour values of direction A "Küchentisch" (specs/17-design-system.md). Every text
/// pair here was checked for WCAG AA; `test/app/theme_test.dart` re-checks them, so
/// change a value there first and let the test tell you whether it still passes.
///
/// Widgets never read this file directly — they go through [ColorScheme] and the
/// `WwColors` theme extension, which pick the right variant for light, dark and night.

/// The three grounds the app is drawn on. Night is the kiosk after 21:00: warm amber
/// on near-black, deliberately lower contrast than dark so the wall does not glare.
enum Shade { light, dark, night }

/// Neutrals, brand and semantics for one [Shade].
@immutable
class ShadeColors {
  const ShadeColors({
    required this.bg,
    required this.surface,
    required this.sunken,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.brand,
    required this.onBrand,
    required this.brandTint,
    required this.onBrandTint,
    required this.danger,
    required this.onDanger,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color bg;
  final Color surface;
  final Color sunken;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// "Tanne": the no-profile accent, primary actions and success. Green means done,
  /// which is why no member colour is green.
  final Color brand;
  final Color onBrand;
  final Color brandTint;
  final Color onBrandTint;

  final Color danger;
  final Color onDanger;

  /// Always shown with an icon: amber is also a member colour.
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
}

abstract final class Palette {
  static const light = ShadeColors(
    bg: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFEFEBE3),
    line: Color(0xFFDDD8CF),
    ink: Color(0xFF1C1F23),
    ink2: Color(0xFF4A5058),
    ink3: Color(0xFF656B75),
    brand: Color(0xFF2D6A4F),
    onBrand: Color(0xFFFFFFFF),
    brandTint: Color(0xFFDCEBE2),
    onBrandTint: Color(0xFF133A2A),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFCEFD2),
    onWarningContainer: Color(0xFF5C3D00),
  );

  static const dark = ShadeColors(
    bg: Color(0xFF14171A),
    surface: Color(0xFF1C2024),
    sunken: Color(0xFF101315),
    line: Color(0xFF2E343A),
    ink: Color(0xFFECE8E1),
    ink2: Color(0xFFB5B2AB),
    ink3: Color(0xFF8E8B85),
    brand: Color(0xFF6CC79A),
    onBrand: Color(0xFF0C2A1D),
    brandTint: Color(0xFF1D3A2C),
    onBrandTint: Color(0xFFBDE8D0),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF14171A),
    warning: Color(0xFFE9B949),
    warningContainer: Color(0xFF3A2E12),
    onWarningContainer: Color(0xFFF6DDA0),
  );

  static const night = ShadeColors(
    bg: Color(0xFF0B0A09),
    surface: Color(0xFF15130F),
    sunken: Color(0xFF080706),
    line: Color(0xFF2B261F),
    ink: Color(0xFFCDB994),
    ink2: Color(0xFFA8977A),
    ink3: Color(0xFF938366),
    brand: Color(0xFFE0A458),
    onBrand: Color(0xFF1E1406),
    brandTint: Color(0xFF2A2013),
    onBrandTint: Color(0xFFE8C590),
    danger: Color(0xFFE08A7A),
    onDanger: Color(0xFF0B0A09),
    warning: Color(0xFFE0A458),
    warningContainer: Color(0xFF2A2013),
    onWarningContainer: Color(0xFFE8C590),
  );

  static ShadeColors of(Shade shade) => switch (shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => night,
  };

  /// "Punkte-Gold": point coins, the balance, badges. The same in every shade.
  static const points = Color(0xFFF2B705);
  static const onPoints = Color(0xFF3E2A00);
}

/// One member colour in all three shades. People are ink (specs/17): saturated, used
/// for bands, dots, avatars and the active accent — always next to an initial.
@immutable
class MemberSwatch {
  const MemberSwatch({
    required this.key,
    required this.light,
    required this.dark,
    required this.night,
    required this.tintLight,
    required this.tintDark,
    required this.tintNight,
  });

  final String key;
  final Color light;
  final Color dark;
  final Color night;
  final Color tintLight;
  final Color tintDark;
  final Color tintNight;

  Color ink(Shade shade) => switch (shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => night,
  };

  Color tint(Shade shade) => switch (shade) {
    Shade.light => tintLight,
    Shade.dark => tintDark,
    Shade.night => tintNight,
  };

  /// Text on a filled [ink]: white on the light inks, the ground on dark and night.
  Color onInk(Shade shade) => switch (shade) {
    Shade.light => const Color(0xFFFFFFFF),
    Shade.dark => Palette.dark.bg,
    Shade.night => Palette.night.bg,
  };
}

abstract final class MemberPalette {
  /// In the order the picker offers them. The first four are the most separable set
  /// for every kind of colour vision; the fifth keeps five members apart; from the
  /// sixth on, the initial carries identity (specs/17, "Member colours").
  static const swatches = <MemberSwatch>[
    MemberSwatch(
      key: 'violet',
      light: Color(0xFF7B3FE4),
      dark: Color(0xFFC3A6FF),
      night: Color(0xFF8F7ABA),
      tintLight: Color(0xFFEDE4FB),
      tintDark: Color(0xFF3D3B50),
      tintNight: Color(0xFF342D3A),
    ),
    MemberSwatch(
      key: 'petrol',
      light: Color(0xFF08737F),
      dark: Color(0xFF4FCBD6),
      night: Color(0xFF3C959D),
      tintLight: Color(0xFFDCEBED),
      tintDark: Color(0xFF264248),
      tintNight: Color(0xFF1F3433),
    ),
    MemberSwatch(
      key: 'amber',
      light: Color(0xFF9A5300),
      dark: Color(0xFFF0A84E),
      night: Color(0xFFB07C3B),
      tintLight: Color(0xFFF1E7DB),
      tintDark: Color(0xFF463B2C),
      tintNight: Color(0xFF3C2D1A),
    ),
    MemberSwatch(
      key: 'raspberry',
      light: Color(0xFFC2255C),
      dark: Color(0xFFFF85AE),
      night: Color(0xFFBB6380),
      tintLight: Color(0xFFF6E0E8),
      tintDark: Color(0xFF493440),
      tintNight: Color(0xFF3E272B),
    ),
    MemberSwatch(
      key: 'cocoa',
      light: Color(0xFF7A4A2A),
      dark: Color(0xFFD9A684),
      night: Color(0xFF9F7A62),
      tintLight: Color(0xFFECE6E1),
      tintDark: Color(0xFF423B37),
      tintNight: Color(0xFF382D24),
    ),
    MemberSwatch(
      key: 'ocean',
      light: Color(0xFF1A4FA8),
      dark: Color(0xFF86B4FF),
      night: Color(0xFF6484BA),
      tintLight: Color(0xFFDFE6F3),
      tintDark: Color(0xFF313E50),
      tintNight: Color(0xFF292F3A),
    ),
    MemberSwatch(
      key: 'mustard',
      light: Color(0xFF736200),
      dark: Color(0xFFE3C83A),
      night: Color(0xFFA7932C),
      tintLight: Color(0xFFEBE9DB),
      tintDark: Color(0xFF444228),
      tintNight: Color(0xFF3A3316),
    ),
    MemberSwatch(
      key: 'orchid',
      light: Color(0xFFA0309E),
      dark: Color(0xFFF08AE8),
      night: Color(0xFFB066AA),
      tintLight: Color(0xFFF2E2F1),
      tintDark: Color(0xFF46354B),
      tintNight: Color(0xFF3C2836),
    ),
  ];

  /// The swatch for a stored `profile.colour_hex`. The picker stores a swatch's
  /// [MemberSwatch.light] value, so this is normally an exact match; anything else
  /// (rows written before the palette existed) snaps to the nearest swatch, so every
  /// member renders with verified contrast in every shade.
  static MemberSwatch resolve(Color stored) {
    final argb = stored.toARGB32() | 0xFF000000;
    for (final s in swatches) {
      if (s.light.toARGB32() == argb) return s;
    }
    double distance(Color a, Color b) {
      final dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
      return dr * dr + dg * dg + db * db;
    }

    return swatches.reduce(
      (best, s) =>
          distance(s.light, stored) < distance(best.light, stored) ? s : best,
    );
  }
}

/// Pale grounds for subjects, chores and shopping categories. Things are paper: text
/// on them is always the shade's `ink`, and the icon — not the tint — identifies them.
@immutable
class PaperTint {
  const PaperTint(this.key, this.light, this.dark);

  final String key;
  final Color light;
  final Color dark;

  /// Night has no tints of its own: the dark tint is already quiet enough.
  Color of(Shade shade) => shade == Shade.light ? light : dark;
}

abstract final class PaperTints {
  static const tints = <PaperTint>[
    PaperTint('blue', Color(0xFFDCE8FA), Color(0xFF1D2A3D)),
    PaperTint('rose', Color(0xFFF9DDE3), Color(0xFF3A1F26)),
    PaperTint('lilac', Color(0xFFE6DEFA), Color(0xFF2A2140)),
    PaperTint('leaf', Color(0xFFDCEFD8), Color(0xFF1F3220)),
    PaperTint('peach', Color(0xFFFCE2CA), Color(0xFF3D2817)),
    PaperTint('lemon', Color(0xFFF6ECB6), Color(0xFF373011)),
    PaperTint('mint', Color(0xFFD2EEEA), Color(0xFF173431)),
    PaperTint('stone', Color(0xFFE8E4DC), Color(0xFF2C2A26)),
  ];
}

/// The six parts of the app a person moves between, plus settings. Each has a pale
/// band (specs/26 "Module bands"): modules are paper like subjects, so any hue is
/// allowed, and the member inks stay the loudest colour on screen.
enum AppModule { today, calendar, schedule, tasks, meals, shopping, settings }

/// One module's band. Night has none: the night theme stays as specs/17 has it.
@immutable
class ModuleBand {
  const ModuleBand(this.module, this.light, this.dark);

  final AppModule module;
  final Color light;
  final Color dark;

  Color of(Shade shade) => switch (shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => Palette.night.surface,
  };
}

abstract final class ModuleBands {
  /// Text on a band is `ink` or `ink2`, never `ink3`: that fails AA on most of them.
  /// Every member ink reaches 4.5:1 on every band, so a member chip may sit on one.
  static const bands = <ModuleBand>[
    ModuleBand(AppModule.today, Color(0xFFFFF0C2), Color(0xFF3A3216)), // sonne
    ModuleBand(
      AppModule.calendar,
      Color(0xFFDCEBFF),
      Color(0xFF1B2B40),
    ), // himmel
    ModuleBand(
      AppModule.schedule,
      Color(0xFFEEE8FF),
      Color(0xFF2A2342),
    ), // flieder
    ModuleBand(
      AppModule.tasks,
      Color(0xFFFFE1D6),
      Color(0xFF3D2420),
    ), // koralle
    ModuleBand(
      AppModule.meals,
      Color(0xFFFFE5C7),
      Color(0xFF3B2A18),
    ), // aprikose
    ModuleBand(
      AppModule.shopping,
      Color(0xFFD5F2E6),
      Color(0xFF173429),
    ), // minze
    ModuleBand(
      AppModule.settings,
      Color(0xFFECE8E0),
      Color(0xFF26282B),
    ), // stein
  ];

  static ModuleBand of(AppModule module) =>
      bands.firstWhere((b) => b.module == module);
}

/// Colours for illustration only (specs/26 "Decoration"): blobs, confetti, the
/// look-back's cards and the kid register's offset shadows. They carry no meaning.
/// Text on them is `ink` in light and the dark ground in dark; at night they fade
/// into the surface.
enum Decor {
  sun(Color(0xFFFFC94D), Color(0xFFC9A23E)),
  sky(Color(0xFF8EC5FF), Color(0xFF6E9BCB)),
  coral(Color(0xFFFF9F85), Color(0xFFCC8370)),
  apricot(Color(0xFFFFB570), Color(0xFFB7834F)),
  mint(Color(0xFF7FD8B5), Color(0xFF4E9A7E)),
  lilac(Color(0xFFB9A3FF), Color(0xFF9585D4));

  const Decor(this.light, this.dark);

  final Color light;
  final Color dark;

  Color of(Shade shade) => switch (shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => Palette.night.line,
  };

  /// Text on this decoration.
  static Color onDecor(Shade shade) => switch (shade) {
    Shade.light => Palette.light.ink,
    Shade.dark => Palette.dark.bg,
    Shade.night => Palette.night.ink,
  };
}

/// The wall's sky through the day (specs/26 "Day phases"), top to bottom. Text over a
/// sky is `ink` or `ink2` of light; member inks never sit on it.
enum SkyPhase {
  morning(Color(0xFFFFD9B8), Color(0xFFFFF3E4), Color(0xFFFFC94D)),
  day(Color(0xFFCFE6FF), Color(0xFFF2F8FF), Color(0xFFFFE27A)),
  evening(Color(0xFFFFC9A8), Color(0xFFEBD9F2), Color(0xFFFF9F85)),
  night(Color(0xFF0B0A09), Color(0xFF1A1630), Color(0xFFCDB994));

  const SkyPhase(this.top, this.bottom, this.orb);

  final Color top;
  final Color bottom;

  /// The sun, or at night the moon.
  final Color orb;
}
