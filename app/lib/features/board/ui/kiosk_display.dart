import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/logging/log.dart';

/// While the week board is on screen the wall display stays awake and shows no system
/// bars (specs/09 "The wall display": the app keeps the screen on; the night variant
/// dims it). Leaving the board — or the kiosk register — hands both back to the system.
class KioskDisplay extends StatefulWidget {
  const KioskDisplay({required this.child, super.key});

  final Widget child;

  @override
  State<KioskDisplay> createState() => _KioskDisplayState();
}

class _KioskDisplayState extends State<KioskDisplay> {
  static const _channel = MethodChannel('wuselwall/kiosk');

  @override
  void initState() {
    super.initState();
    _apply(on: true);
  }

  @override
  void dispose() {
    _apply(on: false);
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
