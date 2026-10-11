import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

extension UiRegisterLabel on UiRegister {
  String label(AppLocalizations l10n) => switch (this) {
    UiRegister.adult => l10n.registerAdult,
    UiRegister.kid => l10n.registerKid,
    UiRegister.kiosk => l10n.registerKiosk,
  };
}
