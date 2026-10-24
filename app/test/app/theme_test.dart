import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void expectAA(Color fg, Color bg, String reason) => expect(
  contrast(fg, bg),
  greaterThanOrEqualTo(4.5),
  reason: '$reason: ${contrast(fg, bg).toStringAsFixed(2)} : 1',
);

void main() {
  test('type scale and touch targets step up per register (specs/09)', () {
    final adult = AppTheme.build(UiRegister.adult, Shade.light);
    final kid = AppTheme.build(UiRegister.kid, Shade.light);
    final kiosk = AppTheme.build(UiRegister.kiosk, Shade.light);

    expect(adult.textTheme.bodyMedium!.fontSize, closeTo(15, 0.01));
    expect(kid.textTheme.bodyMedium!.fontSize, closeTo(19, 0.01));
    expect(kiosk.textTheme.bodyMedium!.fontSize, closeTo(28, 0.01));

    for (final entry in {
      UiRegister.adult: adult,
      UiRegister.kid: kid,
      UiRegister.kiosk: kiosk,
    }.entries) {
      final size = entry.value.filledButtonTheme.style!.minimumSize!.resolve(
        {},
      )!;
      expect(size.height, entry.key.touchTarget, reason: entry.key.name);
    }
  });

  test('kiosk body text respects the 24 px floor (NFR-16)', () {
    final kiosk = AppTheme.build(UiRegister.kiosk, Shade.night);
    expect(
      kiosk.textTheme.bodyMedium!.fontSize,
      greaterThanOrEqualTo(UiRegister.kiosk.minFontSize),
    );
  });

  test('every theme uses the bundled UI face', () {
    for (final shade in Shade.values) {
      final theme = AppTheme.build(UiRegister.adult, shade);
      expect(
        theme.textTheme.bodyMedium!.fontFamily,
        'AtkinsonHyperlegibleNext',
      );
    }
  });

  group('WCAG AA in every shade (specs/17)', () {
    for (final shade in Shade.values) {
      test(shade.name, () {
        final c = Palette.of(shade);
        for (final ground in {
          'bg': c.bg,
          'surface': c.surface,
          'sunken': c.sunken,
        }.entries) {
          expectAA(c.ink, ground.value, 'ink on ${ground.key}');
          expectAA(c.ink2, ground.value, 'ink2 on ${ground.key}');
          expectAA(c.ink3, ground.value, 'ink3 on ${ground.key}');
        }
        expectAA(c.brand, c.bg, 'brand on bg');
        expectAA(c.onBrand, c.brand, 'onBrand on brand');
        expectAA(c.onBrandTint, c.brandTint, 'onBrandTint on brandTint');
        expectAA(c.danger, c.bg, 'danger on bg');
        expectAA(c.onDanger, c.danger, 'onDanger on danger');
        expectAA(c.warning, c.bg, 'warning on bg');
        expectAA(
          c.onWarningContainer,
          c.warningContainer,
          'onWarningContainer on warningContainer',
        );

        for (final m in MemberPalette.swatches) {
          final ink = m.ink(shade);
          expectAA(ink, c.bg, '${m.key} on bg');
          expectAA(ink, c.surface, '${m.key} on surface');
          expectAA(m.onInk(shade), ink, 'text on ${m.key}');
          expectAA(c.ink, m.tint(shade), 'ink on ${m.key} tint');
          if (shade != Shade.night) {
            expectAA(ink, c.sunken, '${m.key} on sunken');
            expectAA(ink, m.tint(shade), '${m.key} on its tint');
          }
        }
        for (final t in PaperTints.tints) {
          expectAA(c.ink, t.of(shade), 'ink on ${t.key} paper');
        }
      });
    }

    test('points gold', () {
      expectAA(Palette.onPoints, Palette.points, 'onPoints on points');
    });
  });

  group('member palette', () {
    test('no member is green or red: those mean done and danger', () {
      for (final m in MemberPalette.swatches) {
        final hue = HSLColor.fromColor(m.light).hue;
        expect(hue < 90 || hue > 170, isTrue, reason: '${m.key} looks green');
        expect(hue > 15 && hue < 345, isTrue, reason: '${m.key} looks red');
      }
    });

    test('a stored swatch resolves exactly; anything else snaps to one', () {
      for (final m in MemberPalette.swatches) {
        expect(MemberPalette.resolve(m.light), same(m));
      }
      // The pre-palette default colour.
      expect(
        MemberPalette.swatches,
        contains(MemberPalette.resolve(const Color(0xFF2E7D6B))),
      );
    });

    test('the acting member becomes the accent', () {
      final base = AppTheme.build(UiRegister.kiosk, Shade.dark);
      final emma = MemberPalette.swatches.first;
      final themed = AppTheme.forMember(base, emma.light);
      expect(themed.colorScheme.primary, emma.dark);
      expect(themed.extension<WwColors>()!.shade, Shade.dark);
    });
  });

  test('QR codes are dark on light with strong contrast in every shade', () {
    for (final shade in Shade.values) {
      final ww = WwColors(shade: shade);
      expect(
        ww.qrInk.computeLuminance(),
        lessThan(ww.qrPaper.computeLuminance()),
        reason: shade.name,
      );
      expect(
        contrast(ww.qrInk, ww.qrPaper),
        greaterThanOrEqualTo(7),
        reason: '${shade.name}: ${contrast(ww.qrInk, ww.qrPaper)} : 1',
      );
    }
  });

  group('night', () {
    test('runs from 21:00 to 06:00', () {
      expect(isNightAt(DateTime(2026, 10, 12, 20, 59)), isFalse);
      expect(isNightAt(DateTime(2026, 10, 12, 21)), isTrue);
      expect(isNightAt(DateTime(2026, 10, 13, 5, 59)), isTrue);
      expect(isNightAt(DateTime(2026, 10, 13, 6)), isFalse);
    });

    test('the next boundary is the next 06:00 or 21:00', () {
      expect(
        nextNightBoundary(DateTime(2026, 10, 12, 14)),
        DateTime(2026, 10, 12, 21),
      );
      expect(
        nextNightBoundary(DateTime(2026, 10, 12, 21)),
        DateTime(2026, 10, 13, 6),
      );
      expect(
        nextNightBoundary(DateTime(2026, 10, 13, 3)),
        DateTime(2026, 10, 13, 6),
      );
    });
  });

  group('a lighter day (specs/26)', () {
    test(
      'ink and ink2 reach AA on every module band, ink3 is not used there',
      () {
        for (final shade in [Shade.light, Shade.dark]) {
          final c = Palette.of(shade);
          for (final band in ModuleBands.bands) {
            final ground = band.of(shade);
            final where = '${band.module.name} (${shade.name})';
            expectAA(c.ink, ground, 'ink on $where');
            expectAA(c.ink2, ground, 'ink2 on $where');
          }
        }
      },
    );

    test(
      'every member ink reaches AA on every band, so a chip may sit on one',
      () {
        for (final shade in [Shade.light, Shade.dark]) {
          for (final band in ModuleBands.bands) {
            for (final m in MemberPalette.swatches) {
              expectAA(
                m.ink(shade),
                band.of(shade),
                '${m.key} on ${band.module.name} (${shade.name})',
              );
            }
          }
        }
      },
    );

    test('text on decoration reaches AA', () {
      for (final shade in [Shade.light, Shade.dark]) {
        for (final d in Decor.values) {
          expectAA(
            Decor.onDecor(shade),
            d.of(shade),
            'text on ${d.name} (${shade.name})',
          );
        }
      }
    });

    test('ink and ink2 reach AA on every stop of the daytime skies', () {
      for (final phase in [SkyPhase.morning, SkyPhase.day, SkyPhase.evening]) {
        for (final stop in [phase.top, phase.bottom]) {
          expectAA(Palette.light.ink, stop, 'ink on ${phase.name}');
          expectAA(Palette.light.ink2, stop, 'ink2 on ${phase.name}');
        }
      }
      for (final stop in [SkyPhase.night.top, SkyPhase.night.bottom]) {
        expectAA(Palette.night.ink, stop, 'night ink on the night sky');
        expectAA(Palette.night.ink2, stop, 'night ink2 on the night sky');
      }
    });

    test('no band, decoration or sky is green or red', () {
      bool greenOrRed(Color c) {
        final hsl = HSLColor.fromColor(c);
        final h = hsl.hue;
        // Saturated green (done) or red (danger); pale mint paper is allowed.
        return hsl.saturation > 0.5 &&
            hsl.lightness < 0.6 &&
            ((h >= 90 && h <= 160) || h < 8 || h > 352);
      }

      for (final band in ModuleBands.bands) {
        expect(greenOrRed(band.light), isFalse, reason: band.module.name);
      }
      for (final d in Decor.values) {
        expect(greenOrRed(d.light), isFalse, reason: d.name);
      }
    });
  });
}
