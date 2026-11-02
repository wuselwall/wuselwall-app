import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gives the system bars the colour of what sits next to them. Android before 15
/// does not draw apps behind its navigation bar and paints that bar black unless told
/// otherwise: a black band under the paper-coloured page that iOS never shows. Android
/// 15 and later draw behind both bars and ignore the colours; the icon brightness
/// still follows the shade. A region at the bottom of the screen decides the
/// navigation bar, so the bottom bars wrap themselves in one with their own colour.
class SystemBars extends StatelessWidget {
  const SystemBars({
    required this.navigationColor,
    required this.child,
    super.key,
  });

  /// The surface along the bottom edge: the page, or a bottom bar.
  final Color navigationColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(navigationColor) ==
        Brightness.dark;
    final icons = dark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: navigationColor,
        systemNavigationBarDividerColor: navigationColor,
        systemNavigationBarIconBrightness: icons,
      ),
      child: child,
    );
  }
}
