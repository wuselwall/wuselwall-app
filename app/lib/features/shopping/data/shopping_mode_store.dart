import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/features/shopping/domain/shopping_mode.dart';

/// The last mode of this device, kept across restarts: a phone closed in the store opens
/// into the trip again. Per device, like the appearance.
abstract class ShoppingModeStore {
  Future<ShoppingMode> read();

  Future<void> write(ShoppingMode mode);
}

class SecureShoppingModeStore implements ShoppingModeStore {
  SecureShoppingModeStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.shopping.mode';

  final FlutterSecureStorage _storage;

  @override
  Future<ShoppingMode> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return ShoppingMode.values.where((m) => m.name == raw).firstOrNull ??
          ShoppingMode.plan;
    } on Object catch (error, stack) {
      logError(
        'Reading the shopping mode failed',
        error: error,
        stackTrace: stack,
      );
      return ShoppingMode.plan;
    }
  }

  @override
  Future<void> write(ShoppingMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } on Object catch (error, stack) {
      logError(
        'Saving the shopping mode failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

/// The mode in memory: the demo, and tests (secure storage has no platform there).
class MemoryShoppingModeStore implements ShoppingModeStore {
  MemoryShoppingModeStore([this.mode = ShoppingMode.plan]);

  ShoppingMode mode;

  @override
  Future<ShoppingMode> read() async => mode;

  @override
  Future<void> write(ShoppingMode mode) async => this.mode = mode;
}

final shoppingModeStoreProvider = Provider<ShoppingModeStore>(
  (ref) => SecureShoppingModeStore(),
);
