import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:wuselwall/core/server/setup_link.dart';

/// Reloads the page when the fragment turns into a setup link (see setup_link_watch.dart).
void watchSetupLinks() {
  web.window.addEventListener(
    'hashchange',
    ((web.Event _) {
      if (parseSetupLink(web.window.location.href) != null) {
        web.window.location.reload();
      }
    }).toJS,
  );
}
