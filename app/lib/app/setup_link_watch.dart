// A setup link opened in an already running web app changes only the fragment, so the
// page does not load again and main() never sees it. Reload then: the start-up path
// captures the setup code, applies the server rules and removes it from the address bar.
export 'setup_link_watch_stub.dart'
    if (dart.library.js_interop) 'setup_link_watch_web.dart';
