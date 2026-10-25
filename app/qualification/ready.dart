import 'package:flutter/material.dart';

import 'inventory.g.dart';

/// Test-only marker emitted after the real destination exists and indeterminate
/// loading completes. Image rendering is checked by screenshot stabilization.
class QualificationReady extends StatefulWidget {
  const QualificationReady({
    required this.id,
    required this.destination,
    required this.child,
    super.key,
  });
  final String id;
  final String destination;
  final Widget child;

  @override
  State<QualificationReady> createState() => _QualificationReadyState();
}

class _QualificationReadyState extends State<QualificationReady> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_check);
  }

  void _check(Duration _) {
    if (!mounted) return;
    var destination = false;
    var loading = false;
    void visit(Element element) {
      final current = element.widget;
      if (isQualificationDestination(current, widget.destination)) {
        destination = true;
      }
      if (current is CircularProgressIndicator && current.value == null ||
          current is LinearProgressIndicator && current.value == null) {
        loading = true;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (destination && !loading) {
      setState(() => _ready = true);
    } else {
      // Future completions schedule the next frame; no timer or arbitrary delay.
      WidgetsBinding.instance.addPostFrameCallback(_check);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    identifier: _ready ? 'qualification-ready-${widget.id}' : null,
    child: widget.child,
  );
}
