import 'package:web/web.dart' as web;

// Only imported by the dedicated qualification entry point.
void setQualificationReady(String? id) {
  final body = web.document.body;
  if (id == null) {
    body?.removeAttribute('data-qualification-ready');
  } else {
    body?.setAttribute('data-qualification-ready', id);
  }
}
