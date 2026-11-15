import 'package:flutter/material.dart';

/// Colour values of direction A "Küchentisch" (specs/17-design-system.md). Every text
/// pair here was checked for WCAG AA; `test/app/theme_test.dart` re-checks them for
/// every theme, so change a value there first and let the test tell you whether it
/// still passes.
///
/// Widgets never read this file directly — they go through [ColorScheme] and the
/// `WwColors` theme extension, which pick the right variant for the device's theme.

/// The three grounds the app is drawn on. Night is the kiosk after 21:00: warm amber
/// on near-black, deliberately lower contrast than dark so the wall does not glare.
enum Shade { light, dark, night }

/// A colour theme (specs/17 "Themes"): the neutrals of one [Shade]. A device chooses
/// one light and one dark theme (`looksProvider`); the member inks, the tints, the
/// bands and the decoration belong to the shade and are the same in each of its themes,
/// so the colour-vision checks of the member palette hold for all of them.
enum Look {
  /// Cool, minty white paper. The light theme a device starts with.
  frisch(Shade.light),

  /// Sunny cream paper with warm brown ink.
  sonnig(Shade.light),

  /// An evening-blue ground with warm, lamp-lit ink. The dark theme a device starts
  /// with.
  blaueStunde(Shade.dark),

  /// A cool grey ground, the quietest of the dark themes.
  schiefer(Shade.dark),

  /// A dusk-violet ground.
  pflaume(Shade.dark),

  /// A warm brown ground: the kitchen table by lamp light.
  kakao(Shade.dark),

  /// The kiosk's night. Not a choice: the wall takes it in its night hours.
  night(Shade.night);

  const Look(this.shade);

  final Shade shade;

  /// The theme a device shows for [shade] until someone chooses another.
  static Look standard(Shade shade) => switch (shade) {
    Shade.light => frisch,
    Shade.dark => blaueStunde,
    Shade.night => night,
  };

  /// The themes a device can choose for [shade], the standard one first.
  static List<Look> choices(Shade shade) => [
    for (final look in values)
      if (look.shade == shade) look,
  ];

  /// The theme stored under [name] if it is one of [shade]; null for anything else, so
  /// a value this app cannot read falls back to the standard theme.
  static Look? named(String? name, Shade shade) => values
      .where((look) => look.name == name && look.shade == shade)
      .firstOrNull;
}

/// Neutrals, brand and semantics for one [Look].
@immutable
class ShadeColors {
  const ShadeColors({
    required this.bg,
    required this.surface,
    required this.sunken,
    required this.line,
    required this.outline,
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
    required this.stone,
    required this.settingsBand,
  });

  final Color bg;
  final Color surface;
  final Color sunken;
  final Color line;

  /// A control's resting edge (fields, outlined buttons, segments): lighter than
  /// [ink3], so a form does not read as a grid of dark boxes, yet 3.2 : 1 or more on
  /// bg, surface and sunken, the non-text contrast a control needs (WCAG 1.4.11).
  /// [line] is far below that, which is why it only separates.
  final Color outline;
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

  /// The neutral paper tint ([PaperTints], `stone`) and the Settings band
  /// ([ModuleBands]): the two tints without a hue of their own, so they lean toward
  /// the theme's ground instead.
  final Color stone;
  final Color settingsBand;
}

abstract final class Palette {
  /// Cool, minty white paper.
  static const frisch = ShadeColors(
    bg: Color(0xFFF5F9F5),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFE9F0E9),
    line: Color(0xFFD4DCD4),
    outline: Color(0xFF7E828A),
    ink: Color(0xFF1C1F23),
    ink2: Color(0xFF4A5058),
    ink3: Color(0xFF656B75),
    brand: Color(0xFF177148),
    onBrand: Color(0xFFFFFFFF),
    brandTint: Color(0xFFD1F3DF),
    onBrandTint: Color(0xFF0B3A27),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFCEFD2),
    onWarningContainer: Color(0xFF5C3D00),
    stone: Color(0xFFE0E7E0),
    settingsBand: Color(0xFFE5ECE5),
  );

  /// Sunny cream paper; the ink is a warm brown-black.
  static const sonnig = ShadeColors(
    bg: Color(0xFFFFF6DA),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFFCECC1),
    line: Color(0xFFE4D4AC),
    outline: Color(0xFF8B7D73),
    ink: Color(0xFF2A1F17),
    ink2: Color(0xFF5C4C40),
    ink3: Color(0xFF77675A),
    brand: Color(0xFF177148),
    onBrand: Color(0xFFFFFFFF),
    brandTint: Color(0xFFD1F3DF),
    onBrandTint: Color(0xFF0B3A27),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFCEFD2),
    onWarningContainer: Color(0xFF5C3D00),
    stone: Color(0xFFF0E5CC),
    settingsBand: Color(0xFFF6EACD),
  );

  /// An evening-blue ground.
  static const blaueStunde = ShadeColors(
    bg: Color(0xFF151D33),
    surface: Color(0xFF1E2841),
    sunken: Color(0xFF0E1528),
    line: Color(0xFF333F5D),
    outline: Color(0xFF75809C),
    ink: Color(0xFFF2EEE6),
    ink2: Color(0xFFC8C4BC),
    ink3: Color(0xFFA39F98),
    brand: Color(0xFF6DD6A2),
    onBrand: Color(0xFF09281B),
    brandTint: Color(0xFF1B4A34),
    onBrandTint: Color(0xFFC0EED4),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF151D33),
    warning: Color(0xFFE9B949),
    warningContainer: Color(0xFF4E3D16),
    onWarningContainer: Color(0xFFF6DDA0),
    stone: Color(0xFF303A52),
    settingsBand: Color(0xFF273352),
  );

  /// A cool grey ground.
  static const schiefer = ShadeColors(
    bg: Color(0xFF191F25),
    surface: Color(0xFF232A30),
    sunken: Color(0xFF12171C),
    line: Color(0xFF394148),
    outline: Color(0xFF7A8188),
    ink: Color(0xFFF2EEE6),
    ink2: Color(0xFFC8C4BC),
    ink3: Color(0xFFA39F98),
    brand: Color(0xFF6DD6A2),
    onBrand: Color(0xFF09281B),
    brandTint: Color(0xFF1B4A34),
    onBrandTint: Color(0xFFC0EED4),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF191F25),
    warning: Color(0xFFE9B949),
    warningContainer: Color(0xFF4E3D16),
    onWarningContainer: Color(0xFFF6DDA0),
    stone: Color(0xFF353B42),
    settingsBand: Color(0xFF2D353D),
  );

  /// A dusk-violet ground.
  static const pflaume = ShadeColors(
    bg: Color(0xFF251929),
    surface: Color(0xFF312335),
    sunken: Color(0xFF1C111F),
    line: Color(0xFF49394E),
    outline: Color(0xFF897A8E),
    ink: Color(0xFFF2EEE6),
    ink2: Color(0xFFC8C4BC),
    ink3: Color(0xFFA39F98),
    brand: Color(0xFF6DD6A2),
    onBrand: Color(0xFF09281B),
    brandTint: Color(0xFF1B4A34),
    onBrandTint: Color(0xFFC0EED4),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF251929),
    warning: Color(0xFFE9B949),
    warningContainer: Color(0xFF4E3D16),
    onWarningContainer: Color(0xFFF6DDA0),
    stone: Color(0xFF423547),
    settingsBand: Color(0xFF3E2D43),
  );

  /// A warm brown ground; the ink is a shade warmer too.
  static const kakao = ShadeColors(
    bg: Color(0xFF271B15),
    surface: Color(0xFF33261E),
    sunken: Color(0xFF1D130E),
    line: Color(0xFF4C3C33),
    outline: Color(0xFF8C7D75),
    ink: Color(0xFFF4EEE1),
    ink2: Color(0xFFC9C3B7),
    ink3: Color(0xFFA59F94),
    brand: Color(0xFF6DD6A2),
    onBrand: Color(0xFF09281B),
    brandTint: Color(0xFF1B4A34),
    onBrandTint: Color(0xFFC0EED4),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF271B15),
    warning: Color(0xFFE9B949),
    warningContainer: Color(0xFF4E3D16),
    onWarningContainer: Color(0xFFF6DDA0),
    stone: Color(0xFF443730),
    settingsBand: Color(0xFF403027),
  );

  static const night = ShadeColors(
    bg: Color(0xFF0B0A09),
    surface: Color(0xFF15130F),
    sunken: Color(0xFF080706),
    line: Color(0xFF2B261F),
    outline: Color(0xFF71654F),
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
    stone: Color(0xFF2C2A26),
    settingsBand: Color(0xFF15130F),
  );

  /// The standard themes, for colours that do not follow the device's choice.
  static const light = frisch;
  static const dark = blaueStunde;

  static ShadeColors look(Look look) => switch (look) {
    Look.frisch => frisch,
    Look.sonnig => sonnig,
    Look.blaueStunde => blaueStunde,
    Look.schiefer => schiefer,
    Look.pflaume => pflaume,
    Look.kakao => kakao,
    Look.night => night,
  };

  /// The standard theme of [shade].
  static ShadeColors of(Shade shade) => look(Look.standard(shade));

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

  /// Text on a filled [ink]: white on the light inks, the theme's ground on dark and
  /// night.
  Color onInk(Look look) => look.shade == Shade.light
      ? const Color(0xFFFFFFFF)
      : Palette.look(look).bg;
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
      tintDark: Color(0xFF433959),
      tintNight: Color(0xFF342D3A),
    ),
    MemberSwatch(
      key: 'petrol',
      light: Color(0xFF08737F),
      dark: Color(0xFF4FCBD6),
      night: Color(0xFF3C959D),
      tintLight: Color(0xFFDCEBED),
      tintDark: Color(0xFF12484D),
      tintNight: Color(0xFF1F3433),
    ),
    MemberSwatch(
      key: 'amber',
      light: Color(0xFF9A5300),
      dark: Color(0xFFF0A84E),
      night: Color(0xFFB07C3B),
      tintLight: Color(0xFFF1E7DB),
      tintDark: Color(0xFF533A1D),
      tintNight: Color(0xFF3C2D1A),
    ),
    MemberSwatch(
      key: 'raspberry',
      light: Color(0xFFC2255C),
      dark: Color(0xFFFF85AE),
      night: Color(0xFFBB6380),
      tintLight: Color(0xFFF6E0E8),
      tintDark: Color(0xFF58333E),
      tintNight: Color(0xFF3E272B),
    ),
    MemberSwatch(
      key: 'cocoa',
      light: Color(0xFF7A4A2A),
      dark: Color(0xFFD9A684),
      night: Color(0xFF9F7A62),
      tintLight: Color(0xFFECE6E1),
      tintDark: Color(0xFF4A3C33),
      tintNight: Color(0xFF382D24),
    ),
    MemberSwatch(
      key: 'ocean',
      light: Color(0xFF1A4FA8),
      dark: Color(0xFF86B4FF),
      night: Color(0xFF6484BA),
      tintLight: Color(0xFFDFE6F3),
      tintDark: Color(0xFF2E405D),
      tintNight: Color(0xFF292F3A),
    ),
    MemberSwatch(
      key: 'mustard',
      light: Color(0xFF736200),
      dark: Color(0xFFE3C83A),
      night: Color(0xFFA7932C),
      tintLight: Color(0xFFEBE9DB),
      tintDark: Color(0xFF47401B),
      tintNight: Color(0xFF3A3316),
    ),
    MemberSwatch(
      key: 'orchid',
      light: Color(0xFFA0309E),
      dark: Color(0xFFF08AE8),
      night: Color(0xFFB066AA),
      tintLight: Color(0xFFF2E2F1),
      tintDark: Color(0xFF50354E),
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
/// on them is always the theme's `ink`, and the icon — not the tint — identifies them.
@immutable
class PaperTint {
  const PaperTint(this.key, this.light, this.dark, this.night);

  final String key;
  final Color light;
  final Color dark;

  /// Quieter than [dark], so a tile does not glow on the wall at night.
  final Color night;

  Color of(Look look) => switch (look.shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => night,
  };
}

/// The paper without a hue: each theme has its own ([ShadeColors.stone]).
class _StoneTint extends PaperTint {
  const _StoneTint()
    : super(
        'stone',
        const Color(0xFFE0E7E0),
        const Color(0xFF303A52),
        const Color(0xFF2C2A26),
      );

  @override
  Color of(Look look) => Palette.look(look).stone;
}

abstract final class PaperTints {
  static const tints = <PaperTint>[
    PaperTint('blue', Color(0xFFDCE8FA), Color(0xFF283B57), Color(0xFF1D2A3D)),
    PaperTint('rose', Color(0xFFF9DDE3), Color(0xFF562B37), Color(0xFF3A1F26)),
    PaperTint('lilac', Color(0xFFE6DEFA), Color(0xFF3D3454), Color(0xFF2A2140)),
    PaperTint('leaf', Color(0xFFDCEFD8), Color(0xFF274229), Color(0xFF1F3220)),
    PaperTint('peach', Color(0xFFFCE2CA), Color(0xFF54301C), Color(0xFF3D2817)),
    PaperTint('lemon', Color(0xFFF6ECB6), Color(0xFF4D3603), Color(0xFF373011)),
    PaperTint('mint', Color(0xFFD2EEEA), Color(0xFF0D443F), Color(0xFF173431)),
    _StoneTint(),
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

  Color of(Look look) => switch (look.shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => Palette.night.surface,
  };
}

/// Settings stay calm (stein): each theme has its own band ([ShadeColors.settingsBand]).
class _SettingsBand extends ModuleBand {
  const _SettingsBand()
    : super(
        AppModule.settings,
        const Color(0xFFE5ECE5),
        const Color(0xFF273352),
      );

  @override
  Color of(Look look) => Palette.look(look).settingsBand;
}

abstract final class ModuleBands {
  /// Text on a band is `ink` or `ink2`, never `ink3`: that fails AA on most of them.
  /// Every member ink reaches 4.5:1 on every band, so a member chip may sit on one.
  static const bands = <ModuleBand>[
    // sonne
    ModuleBand(AppModule.today, Color(0xFFFFF0C2), Color(0xFF523500)),
    // himmel
    ModuleBand(AppModule.calendar, Color(0xFFDCEBFF), Color(0xFF233D5F)),
    // flieder
    ModuleBand(AppModule.schedule, Color(0xFFEEE8FF), Color(0xFF3E345C)),
    // koralle
    ModuleBand(AppModule.tasks, Color(0xFFFFE1D6), Color(0xFF5F2A20)),
    // aprikose
    ModuleBand(AppModule.meals, Color(0xFFFFE5C7), Color(0xFF573119)),
    // minze
    ModuleBand(AppModule.shopping, Color(0xFFCBF5E4), Color(0xFF094734)),
    _SettingsBand(), // stein
  ];

  static ModuleBand of(AppModule module) =>
      bands.firstWhere((b) => b.module == module);
}

/// Colours for illustration only (specs/26 "Decoration"): blobs, confetti, the
/// look-back's cards and the kid register's offset shadows. They carry no meaning.
/// Text on them is `ink` in light and the theme's ground in dark; at night they fade
/// into the surface.
enum Decor {
  sun(Color(0xFFFFC94D), Color(0xFFE6B73A)),
  sky(Color(0xFF8EC5FF), Color(0xFF78B1EE)),
  coral(Color(0xFFFF9F85), Color(0xFFED937C)),
  apricot(Color(0xFFFFB570), Color(0xFFD69553)),
  mint(Color(0xFF7FD8B5), Color(0xFF50B490)),
  lilac(Color(0xFFB9A3FF), Color(0xFFAB97F7));

  const Decor(this.light, this.dark);

  final Color light;
  final Color dark;

  Color of(Shade shade) => switch (shade) {
    Shade.light => light,
    Shade.dark => dark,
    Shade.night => Palette.night.line,
  };

  /// Text on this decoration.
  static Color onDecor(Look look) => switch (look.shade) {
    Shade.light => Palette.look(look).ink,
    Shade.dark => Palette.look(look).bg,
    Shade.night => Palette.night.ink,
  };
}

/// How a flag's colours are laid out (specs/26 "Seasons and occasions"): stripes from
/// the top or from the hoist, or a field with a cross.
enum FlagLayout { horizontal, vertical, nordicCross, centredCross }

/// A national flag, simplified to what reads at 26 px: stripes or a cross, never an
/// emblem. [colours] are the stripes in order, or for a cross the field, the cross and
/// a Nordic cross's inner cross; [weights] the stripes' relative sizes.
class FlagDesign {
  const FlagDesign(
    this.layout,
    this.colours, {
    this.weights,
    this.square = false,
  });

  final FlagLayout layout;
  final List<Color> colours;
  final List<int>? weights;

  /// Switzerland's flag is square.
  final bool square;
}

/// The flags of the countries with a national day (specs/26), by country code. The
/// colours are the flags' own, so they do not follow the shade. A country missing here
/// has a flag that does not survive simplifying (an emblem, a map, a triangle) and flies
/// a plain pennant.
abstract final class NationalFlags {
  static const _red = Color(0xFFD52B1E);
  static const _white = Color(0xFFFFFFFF);
  static const _blue = Color(0xFF0039A6);
  static const _navy = Color(0xFF002395);
  static const _sky = Color(0xFF4891D9);
  static const _green = Color(0xFF009246);
  static const _yellow = Color(0xFFFFCD00);
  static const _black = Color(0xFF000000);
  static const _orange = Color(0xFFFF883E);
  static const _carmine = Color(0xFF9E3039);

  static const _h = FlagLayout.horizontal;
  static const _v = FlagLayout.vertical;
  static const _nordic = FlagLayout.nordicCross;

  static const designs = <String, FlagDesign>{
    'AD': FlagDesign(_v, [_blue, _yellow, _red]),
    'AT': FlagDesign(_h, [_red, _white, _red]),
    'BE': FlagDesign(_v, [_black, _yellow, _red]),
    'BG': FlagDesign(_h, [_white, _green, _red]),
    'BY': FlagDesign(_h, [_red, _green], weights: [2, 1]),
    'CH': FlagDesign(FlagLayout.centredCross, [_red, _white], square: true),
    'DE': FlagDesign(_h, [_black, _red, _yellow]),
    'DK': FlagDesign(_nordic, [_red, _white]),
    'EE': FlagDesign(_h, [_sky, _black, _white]),
    'ES': FlagDesign(_h, [_red, _yellow, _red], weights: [1, 2, 1]),
    'FI': FlagDesign(_nordic, [_white, _navy]),
    'FR': FlagDesign(_v, [_navy, _white, _red]),
    'GE': FlagDesign(FlagLayout.centredCross, [_white, _red]),
    'GR': FlagDesign(_h, [
      _sky,
      _white,
      _sky,
      _white,
      _sky,
      _white,
      _sky,
      _white,
      _sky,
    ]),
    'HR': FlagDesign(_h, [_red, _white, _blue]),
    'HU': FlagDesign(_h, [_red, _white, _green]),
    'IE': FlagDesign(_v, [_green, _white, _orange]),
    'IS': FlagDesign(_nordic, [_blue, _white, _red]),
    'IT': FlagDesign(_v, [_green, _white, _red]),
    'LI': FlagDesign(_h, [_navy, _red]),
    'LT': FlagDesign(_h, [_yellow, _green, _red]),
    'LU': FlagDesign(_h, [_red, _white, _sky]),
    'LV': FlagDesign(_h, [_carmine, _white, _carmine], weights: [2, 1, 2]),
    'MC': FlagDesign(_h, [_red, _white]),
    'MD': FlagDesign(_v, [_blue, _yellow, _red]),
    'MT': FlagDesign(_v, [_white, _red]),
    'NL': FlagDesign(_h, [_red, _white, _navy]),
    'NO': FlagDesign(_nordic, [_red, _white, _navy]),
    'PL': FlagDesign(_h, [_white, _red]),
    'PT': FlagDesign(_v, [_green, _red], weights: [2, 3]),
    'RO': FlagDesign(_v, [_navy, _yellow, _red]),
    'RS': FlagDesign(_h, [_red, _blue, _white]),
    'RU': FlagDesign(_h, [_white, _blue, _red]),
    'SE': FlagDesign(_nordic, [_blue, _yellow]),
    'SI': FlagDesign(_h, [_white, _blue, _red]),
    'SK': FlagDesign(_h, [_white, _blue, _red]),
    'SM': FlagDesign(_h, [_white, _sky]),
    'UA': FlagDesign(_h, [_blue, _yellow]),
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

/// The sky of the dark themes (specs/26 "Day phases"): a twilight from deep blue down
/// to a warm horizon, the same at every hour. Text over it is the dark theme's `ink`
/// or `ink2`; member inks never sit on it.
abstract final class Twilight {
  static const top = Color(0xFF2B2959);
  static const bottom = Color(0xFF7A342B);
}
