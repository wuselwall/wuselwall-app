import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

extension DeviceClassLabel on DeviceClass {
  String label(AppLocalizations l10n) => switch (this) {
    DeviceClass.personal => l10n.classPersonal,
    DeviceClass.shared => l10n.classShared,
    DeviceClass.kiosk => l10n.classKiosk,
  };
}
