import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/matching/edit_distance.dart';

void main() {
  test('identical strings are 0 apart', () {
    expect(damerauLevenshtein('milch', 'milch'), 0);
    expect(damerauLevenshtein('', ''), 0);
  });

  test('one insertion, deletion or replacement is 1', () {
    expect(damerauLevenshtein('jogurt', 'joghurt'), 1);
    expect(damerauLevenshtein('tomatten', 'tomaten'), 1);
    expect(damerauLevenshtein('kaese', 'kaesa'), 1);
  });

  test('swapping two neighbours is 1', () {
    expect(damerauLevenshtein('milch', 'mlich'), 1);
    expect(damerauLevenshtein('tomaten', 'tomtaen'), 1);
  });

  test('"brokolli" is two steps from "brokkoli", not one swap', () {
    // k-o-l-l-i against k-k-o-l-i: one letter moves and one doubles.
    expect(damerauLevenshtein('brokolli', 'brokkoli'), 2);
  });

  test('empty against a word is its length', () {
    expect(damerauLevenshtein('', 'abc'), 3);
    expect(damerauLevenshtein('abc', ''), 3);
  });

  test('past max the answer is max + 1', () {
    expect(damerauLevenshtein('abc', 'abcdef', max: 2), 3);
    expect(damerauLevenshtein('kitten', 'sitting', max: 1), 2);
    expect(damerauLevenshtein('kitten', 'sitting', max: 3), 3);
    expect(damerauLevenshtein('abcd', 'wxyz', max: 2), 3);
    expect(damerauLevenshtein('', 'abcdef', max: 2), 3);
  });
}
