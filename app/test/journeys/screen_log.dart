import 'package:go_router/go_router.dart';

/// Records the screens a journey shows, for the budgets of NFR-17 (specs/20, "How smooth
/// is checked").
///
/// A screen is a route of the app's router. The log listens to the router's delegate, which
/// notifies on every navigation *and* every redirect (the router moves a signed-in device
/// from the front door to H1, H2 or Today by itself), and keeps the location each time it
/// changes. Dialogs and snackbars are not routes and do not count; a screen that is shown
/// twice in a row counts once. [mark] drops a named point into the sequence, so a test can
/// ask for "the screens after sign-in".
class ScreenLog {
  ScreenLog(this._router) {
    _record();
    _router.routerDelegate.addListener(_record);
  }

  final GoRouter _router;
  final _entries = <({String? mark, String path})>[];

  void _record() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    final last = _entries.where((e) => e.mark == null).lastOrNull;
    if (last == null || last.path != path) {
      _entries.add((mark: null, path: path));
    }
  }

  /// Marks the current point of the journey (the path shown right now stays in the log).
  void mark(String name) => _entries.add((mark: name, path: ''));

  /// Every location shown so far, in order.
  List<String> get all => [
    for (final e in _entries)
      if (e.mark == null) e.path,
  ];

  /// The locations shown after [mark] was set. Each one is a screen of the budget; the
  /// one that was on screen when the mark was set is not repeated.
  List<String> after(String mark) {
    final at = _entries.indexWhere((e) => e.mark == mark);
    if (at < 0) throw StateError('no mark "$mark" in the log');
    return [
      for (final e in _entries.skip(at + 1))
        if (e.mark == null) e.path,
    ];
  }

  void dispose() => _router.routerDelegate.removeListener(_record);
}
