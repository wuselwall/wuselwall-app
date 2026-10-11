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
