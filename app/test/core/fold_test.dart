import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/text/fold.dart';

/// Must agree with `app.fold` in the database: the picker matches on `folded_name`.
void main() {
  test('case, umlauts and accents fold together', () {
    expect(fold('Käse'), 'kaese');
    expect(fold('KÄSE'), 'kaese');
    expect(fold('Straße'), 'strasse');
    expect(fold('Crème fraîche'), 'creme fraiche');
    expect(fold('Öl'), 'oel');
  });
}
