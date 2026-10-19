import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['de', 'en', 'fr', 'es'];
Map<String, dynamic> _catalogue(String code) =>
    jsonDecode(File('l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;
Set<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  for (final code in _languages) {
    group(code, () {
      test('defines exactly the template messages', () {
        final arb = _catalogue(code);
        expect(arb['@@locale'], code);
        expect(_messages(arb), _messages(_catalogue('en')));
        for (final key in _messages(arb)) {
          expect(arb[key], isA<String>(), reason: key);
          expect((arb[key] as String).trim(), isNotEmpty, reason: key);
        }
      });

      test(
        'the account-deletion explanation makes no Apple revocation claim',
        () {
          // Social sign-in was removed; account-delete revokes no Apple token.
          expect(
            _catalogue(code)['accountDeleteExplain'],
            isNot(contains('Apple')),
          );
        },
      );

      test('no ARB message contains an emoji', () {
        // Avoid a remote emoji font (NFR-9); use assets/emoji instead.
        final emoji = RegExp(
          r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}]',
          unicode: true,
        );
        final arb = _catalogue(code);
        for (final key in _messages(arb)) {
          expect(emoji.hasMatch(arb[key] as String), isFalse, reason: key);
        }
      });

      test('preserves placeholders and valid ICU branches', () {
        final template = _catalogue('en');
        final arb = _catalogue(code);
        for (final key in _messages(template)) {
          final expected = _IcuSignature(template[key] as String);
          final actual = _IcuSignature(arb[key] as String);
          expect(actual.placeholders, expected.placeholders, reason: key);
          expect(actual.formats, expected.formats, reason: key);
          expect(
            actual.requiredSelectors,
            expected.requiredSelectors,
            reason: key,
          );
          final metadata = template['@$key'] as Map<String, dynamic>?;
          final placeholders =
              metadata?['placeholders'] as Map<String, dynamic>?;
          if (placeholders != null) {
            // Some messages need no metadata (a plain {name}); only compare what is declared.
            if (actual.placeholders.isNotEmpty) {
              expect(
                actual.placeholders,
                placeholders.keys.toSet(),
                reason: key,
              );
            }
            final translatedMetadata = arb['@$key'] as Map<String, dynamic>?;
            final translated =
                translatedMetadata?['placeholders'] as Map<String, dynamic>?;
            expect(
              translated == null,
              translatedMetadata == null,
              reason: '@$key',
            );
            if (translated != null) {
              expect(
                translated.keys.toSet(),
                placeholders.keys.toSet(),
                reason: '@$key',
              );
              for (final name in placeholders.keys) {
                final declared = placeholders[name] as Map<String, dynamic>;
                expect(
                  (translated[name] as Map<String, dynamic>)['type'],
                  declared['type'],
                  reason: '@$key.$name type',
                );
              }
            }
          }
        }
      });
    });
  }

  test(
    'ICU guard sees nested placeholders and permits locale plural categories',
    () {
      final english = _IcuSignature(
        '{n, plural, =0{none} one{{name}} other{{n} {name}}}',
      );
      final french = _IcuSignature(
        '{n, plural, =0{aucun} one{{name}} many{{n} {name}} other{{n} {name}}}',
      );
      expect(french.placeholders, {'n', 'name'});
      expect(french.formats, english.formats);
      expect(french.requiredSelectors, english.requiredSelectors);
      expect(
        _IcuSignature('{renamed}').placeholders,
        isNot(_IcuSignature('{name}').placeholders),
      );
      expect(
        _IcuSignature('{n, select, other{all}}').formats,
        isNot(english.formats),
      );
    },
  );

  test('ICU guard rejects unbalanced braces and missing other branches', () {
    for (final text in [
      '{n',
      '{n}}',
      '{n, plural, one{one}}',
      '{n, plural, other{{name}',
    ]) {
      expect(() => _IcuSignature(text), throwsFormatException, reason: text);
    }
  });
}

/// Small structural ICU guard for the app's ARB syntax (escaping is not enabled).
/// Translation may add CLDR plural categories, but cannot rename arguments,
/// change plural/select types, lose exact-number/select branches or omit `other`.
/// Flutter gen-l10n remains the authoritative compiler after these safeguards.
class _IcuSignature {
  _IcuSignature(this.text) {
    _message(nested: false);
  }

  final String text;
  final placeholders = <String>{};
  final formats = <String, String>{};
  final requiredSelectors = <String, Set<String>>{};
  var _at = 0;

  Never _invalid() => throw FormatException('Invalid ICU message', text, _at);
  void _space() {
    while (_at < text.length && text[_at].trim().isEmpty) {
      _at++;
    }
  }

  String _token() {
    _space();
    final start = _at;
    while (_at < text.length &&
        !'{},'.contains(text[_at]) &&
        text[_at].trim().isNotEmpty) {
      _at++;
    }
    if (_at == start) _invalid();
    return text.substring(start, _at);
  }

  void _message({required bool nested}) {
    while (_at < text.length) {
      if (text[_at] == '}') {
        if (!nested) _invalid();
        _at++;
        return;
      }
      if (text[_at] == '{') {
        _at++;
        _argument();
      } else {
        _at++;
      }
    }
    if (nested) _invalid();
  }

  void _argument() {
    final name = _token();
    placeholders.add(name);
    _space();
    if (_at >= text.length) _invalid();
    if (text[_at] == '}') {
      _at++;
      return;
    }
    if (text[_at++] != ',') _invalid();
    final type = _token();
    if (!{'plural', 'select', 'selectordinal'}.contains(type)) _invalid();
    if (formats.containsKey(name) && formats[name] != type) _invalid();
    formats[name] = type;
    _space();
    if (_at >= text.length || text[_at++] != ',') _invalid();
    final selectors = <String>{};
    while (true) {
      _space();
      if (_at >= text.length) _invalid();
      if (text[_at] == '}') {
        _at++;
        break;
      }
      final selector = _token();
      if (!selectors.add(selector)) _invalid();
      _space();
      if (_at >= text.length || text[_at++] != '{') _invalid();
      _message(nested: true);
    }
    if (!selectors.contains('other')) _invalid();
    requiredSelectors
        .putIfAbsent(name, () => {})
        .addAll(
          selectors.where(
            (s) => type == 'select' || s.startsWith('=') || s == 'other',
          ),
        );
  }
}
