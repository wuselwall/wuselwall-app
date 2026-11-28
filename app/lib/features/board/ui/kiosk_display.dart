import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/logging/log.dart';

/// While the week board, or a child's simple view on the wall, is on screen the wall
/// display stays awake and shows no system bars (specs/09 "The wall display": the app
/// keeps the screen on; the night variant dims it). Leaving them — or the kiosk register
/// — hands both back to the system.
class KioskDisplay extends StatefulWidget {
  const KioskDisplay({required this.child, super.key});

  final Widget child;

  @override
  State<KioskDisplay> createState() => _KioskDisplayState();
}

class _KioskDisplayState extends State<KioskDisplay> {
  static const _channel = MethodChannel('wuselwall/kiosk');

  /// How many of these are on screen. The board and a child's simple view each hold
  /// one, and for a frame both do while one replaces the other: the screen is handed
  /// back only when the last one has gone.
  static int _holders = 0;

  @override
  void initState() {
    super.initState();
    if (++_holders == 1) _apply(on: true);
  }

  @override
  void dispose() {
    if (--_holders == 0) _apply(on: false);
    super.dispose();
  }

  Future<void> _apply({required bool on}) async {
    // The web build is never the kiosk (specs/09); there is nothing to hold awake.
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
      await SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } on MissingPluginException {
      // Tests and desktop builds have no handler: the board works without it.
    } on PlatformException catch (e) {
      logError('Kiosk display', error: e);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
