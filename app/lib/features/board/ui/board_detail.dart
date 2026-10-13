import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// Opens a tap-through detail over the week board (specs/09 "Touch behaviour"). It
/// fills the screen but for a margin that keeps the board visible behind it, and it
/// closes by itself after [revertAfter] without a touch, so the wall always returns to
/// the week.
Future<void> showBoardDetail(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget body,
  Duration revertAfter = const Duration(seconds: 60),
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: context.l10n.boardBackToWeek,
  barrierColor: Colors.black54,
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Tokens.motionEmphasised,
  pageBuilder: (context, _, _) => _BoardDetail(
    title: title,
    subtitle: subtitle,
    revertAfter: revertAfter,
    body: body,
  ),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);

class _BoardDetail extends StatefulWidget {
  const _BoardDetail({
    required this.title,
    required this.subtitle,
    required this.revertAfter,
    required this.body,
  });

  final String title;
  final String? subtitle;
  final Duration revertAfter;
  final Widget body;

  @override
  State<_BoardDetail> createState() => _BoardDetailState();
}

class _BoardDetailState extends State<_BoardDetail> {
  Timer? _timer;

  void _touch() {
    _timer?.cancel();
    _timer = Timer(widget.revertAfter, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void initState() {
    super.initState();
    _touch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ww = context.ww;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: ww.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.space6,
                    Tokens.space4,
                    Tokens.space4,
                    Tokens.space4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: ww.ink2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Tokens.space4),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(context.l10n.boardBackToWeek),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: ww.line),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
