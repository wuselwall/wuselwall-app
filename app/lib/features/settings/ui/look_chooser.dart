import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// A theme's name in the reader's language.
String lookLabel(AppLocalizations l10n, Look look) => switch (look) {
  Look.frisch => l10n.lookFrisch,
  Look.sonnig => l10n.lookSonnig,
  Look.blaueStunde => l10n.lookBlaueStunde,
  Look.schiefer => l10n.lookSchiefer,
  Look.pflaume => l10n.lookPflaume,
  Look.kakao => l10n.lookKakao,
  // The wall's night is not a choice and is never listed.
  Look.night => '',
};

/// How this device looks (specs/17 "Themes"): light, dark or as the device says, and
/// the theme of each. Opened from Settings, and once by itself on a personal device's
/// first arrival at home ([firstArrival]). Every tap applies at once, to the app behind
/// the sheet too, so the sheet is its own preview.
Future<void> showLookSheet(BuildContext context, {bool firstArrival = false}) =>
    showModalBottomSheet<void>(
      // The navigator's own context: a sheet opened from below a local `Theme` would
      // keep the colours it was opened with instead of following the choice.
      context: Navigator.of(context).context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Barely there, so the app behind shows the chosen colours as they are.
      barrierColor: const Color(0x0A000000),
      builder: (_) => _LookSheet(firstArrival: firstArrival),
    );

class _LookSheet extends ConsumerWidget {
  const _LookSheet({required this.firstArrival});

  final bool firstArrival;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final kiosk =
        ref.watch(deviceProvider).value?.deviceClass == DeviceClass.kiosk;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        0,
        Tokens.space4,
        Tokens.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              firstArrival ? l10n.firstLookTitle : l10n.appearanceTitle,
              style: text.titleLarge,
            ),
          ),
          if (firstArrival) ...[
            const SizedBox(height: Tokens.space1),
            Text(
              l10n.firstLookHelp,
              style: text.bodyMedium?.copyWith(color: context.ww.ink2),
            ),
          ],
          const SizedBox(height: Tokens.space4),
          const LookChooser(),
          if (kiosk) ...[
            const SizedBox(height: Tokens.space3),
            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: context.ww.ink2),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    l10n.appearanceNightNote,
                    style: text.bodyMedium?.copyWith(color: context.ww.ink2),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Tokens.space4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.firstLookDone),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three appearances and the themes of light and of dark. Not a guardian action:
/// it changes nothing for anyone else.
class LookChooser extends ConsumerWidget {
  const LookChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(appearanceProvider).value ?? ThemeMode.system;
    final looks = ref.watch(looksProvider).value ?? const Looks();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.appearanceSystem),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text(l10n.appearanceLight),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text(l10n.appearanceDark),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (chosen) =>
              ref.read(appearanceProvider.notifier).select(chosen.first),
        ),
        if (mode == ThemeMode.system) ...[
          const SizedBox(height: Tokens.space2),
          Text(
            l10n.appearanceSystemHelp,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.ww.ink2),
          ),
        ],
        for (final shade in const [Shade.light, Shade.dark]) ...[
          const SizedBox(height: Tokens.space4),
          Semantics(
            header: true,
            child: Text(
              shade == Shade.light
                  ? l10n.appearanceLookLight
                  : l10n.appearanceLookDark,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: Tokens.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, look) in Look.choices(shade).indexed) ...[
                if (i > 0) const SizedBox(width: Tokens.space2),
                Expanded(
                  child: LookTile(
                    look: look,
                    selected: looks.of(shade) == look,
                    onTap: () => ref.read(looksProvider.notifier).choose(look),
                  ),
                ),
              ],
              // Light has fewer themes than dark: its tiles keep the same width.
              for (
                var i = Look.choices(shade).length;
                i < Look.choices(Shade.dark).length;
                i++
              ) ...[const SizedBox(width: Tokens.space2), const Spacer()],
            ],
          ),
        ],
      ],
    );
  }
}

/// One theme as a small picture of the app in its colours, with its name. The chosen
/// one has a heavier edge and a tick, not a colour alone.
class LookTile extends StatelessWidget {
  const LookTile({
    required this.look,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Look look;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = lookLabel(context.l10n, look);
    const radius = BorderRadius.all(Radius.circular(12));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('look-${look.name}'),
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.25,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: selected ? scheme.primary : scheme.outline,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: CustomPaint(painter: _LookPainter(look)),
                    ),
                  ),
                  // The tick sits on the picture, so a long name keeps its line.
                  if (selected)
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 22,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app in miniature: a band, a card with two lines of text and the brand's tick,
/// and three members' dots, all in [look]'s own colours.
class _LookPainter extends CustomPainter {
  const _LookPainter(this.look);

  final Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Palette.look(look);
    final w = size.width, h = size.height;
    Paint fill(Color colour) => Paint()..color = colour;
    RRect rounded(Rect rect, double r) =>
        RRect.fromRectAndRadius(rect, Radius.circular(r));

    canvas
      ..drawRect(Offset.zero & size, fill(c.bg))
      ..drawRect(
        Rect.fromLTWH(0, 0, w, h * 0.22),
        fill(ModuleBands.of(AppModule.calendar).of(look)),
      );
    final card = rounded(
      Rect.fromLTWH(w * 0.1, h * 0.32, w * 0.8, h * 0.4),
      h * 0.06,
    );
    canvas
      ..drawRRect(card, fill(c.surface))
      ..drawRRect(
        card,
        Paint()
          ..color = c.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawRRect(
        rounded(
          Rect.fromLTWH(w * 0.18, h * 0.42, w * 0.42, h * 0.07),
          h * 0.035,
        ),
        fill(c.ink),
      )
      ..drawRRect(
        rounded(
          Rect.fromLTWH(w * 0.18, h * 0.56, w * 0.28, h * 0.06),
          h * 0.03,
        ),
        fill(c.ink2),
      )
      ..drawCircle(Offset(w * 0.76, h * 0.52), h * 0.085, fill(c.brand));
    for (final (i, swatch) in MemberPalette.swatches.take(3).indexed) {
      canvas.drawCircle(
        Offset(w * (0.2 + i * 0.16), h * 0.86),
        h * 0.055,
        fill(swatch.ink(look.shade)),
      );
    }
  }

  @override
  bool shouldRepaint(_LookPainter old) => old.look != look;
}

/// Offers the choice once, on a personal device's first arrival at home (specs/20 "The
/// first look"): a sheet, not a screen, so no journey gets longer. A device that
/// already runs the app is asked once after the update that brought the themes.
class FirstLookPrompt extends ConsumerStatefulWidget {
  const FirstLookPrompt({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FirstLookPrompt> createState() => _FirstLookPromptState();
}

class _FirstLookPromptState extends ConsumerState<FirstLookPrompt> {
  var _offered = false;

  void _offer() {
    if (_offered) return;
    final looks = ref.read(looksProvider).value;
    final device = ref.read(deviceProvider).value;
    if (looks == null ||
        looks.asked ||
        device?.deviceClass != DeviceClass.personal) {
      return;
    }
    _offered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Asked once, whether the sheet is answered, swiped away or interrupted.
      await ref.read(looksProvider.notifier).markAsked();
      if (mounted) await showLookSheet(context, firstArrival: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(looksProvider)
      ..watch(deviceProvider);
    _offer();
    return widget.child;
  }
}
