import 'package:flutter/material.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

extension SnackBars on BuildContext {
  void showMessage(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showFailure(Failure failure) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure.message(l10n)),
          backgroundColor: Theme.of(this).colorScheme.error,
        ),
      );
  }
}

/// A snackbar with one action, such as "Rückgängig". Takes the messenger rather than a
/// context, so the action still works after the sheet that showed it has closed.
void showUndoSnack(
  ScaffoldMessengerState messenger, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
