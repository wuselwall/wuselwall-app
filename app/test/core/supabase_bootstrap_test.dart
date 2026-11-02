import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/storage/app_secure_storage.dart';
import 'package:wuselwall/core/supabase/secure_session_storage.dart';
import 'package:wuselwall/core/supabase/supabase_bootstrap.dart';

void main() {
  test('the client never takes a session from a link (F2)', () {
    final options = supabaseAuthOptions();
    expect(options.detectSessionInUri, isFalse);
    expect(options.localStorage, isA<SecureSessionStorage>());
  });

  test('secrets stay on this device on iOS (F24)', () {
    expect(
      appSecureStorage.iOptions.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
  });
}
