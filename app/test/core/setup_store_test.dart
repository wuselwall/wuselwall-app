import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/server/setup_link.dart';
import 'package:wuselwall/core/server/setup_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final server = Uri.parse('https://api.example.org');
  const token = '0123456789abcdef01234567';
  late DateTime now;
  SetupStore store() => SetupStore(now: () => now);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime.utc(2026);
  });
  test(
    'retains across auth and store recreation, consumes only explicitly',
    () async {
      await store().save(SetupLink(server, token));
      expect(await store().read(server), token);
      expect(await store().read(server), token);
      await store().clear();
      expect(await store().read(server), isNull);
    },
  );
  test(
    'another origin clears the capability, including a scheme change',
    () async {
      await store().save(SetupLink(server, token));
      expect(await store().read(Uri.parse('http://api.example.org')), isNull);
      expect(await store().read(server), isNull);
    },
  );
  test('expires after a day without extending on reads', () async {
    await store().save(SetupLink(server, token));
    now = now.add(const Duration(hours: 23));
    expect(await store().read(server), token);
    now = now.add(const Duration(hours: 1));
    expect(await store().read(server), isNull);
  });
}
