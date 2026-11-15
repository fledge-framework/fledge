import 'package:flutter_test/flutter_test.dart';
import 'package:fledge_yarn/fledge_yarn.dart';

void main() {
  late VariableStorage storage;

  setUp(() => storage = VariableStorage());

  group('evaluateCondition', () {
    test('respects arithmetic precedence in comparisons', () {
      storage.setNumber('count', 7);
      expect(storage.evaluateCondition(r'$count > 1 + 2 * 3'), false);
      expect(storage.evaluateCondition(r'$count == 1 + 2 * 3'), true);
      expect(storage.evaluateCondition(r'$count >= 2 * 3 + 1'), true);
    });

    test('handles boolean composition', () {
      storage.setBool('hasKey', true);
      storage.setBool('hasMap', false);
      expect(storage.evaluateCondition(r'$hasKey and not $hasMap'), true);
      expect(storage.evaluateCondition(r'$hasKey or $hasMap'), true);
    });

    test('returns false for malformed expressions rather than throwing', () {
      expect(storage.evaluateCondition('1 +'), false);
      expect(storage.evaluateCondition('(unclosed'), false);
    });
  });

  group('executeSet', () {
    test('assigns an expression result', () {
      storage.setNumber('base', 10);
      storage.executeSet(r'$score = $base + 2 * 5');
      expect(storage.getNumber('score'), 20);
    });

    test('compound operators use current value', () {
      storage.setNumber('hp', 10);
      storage.executeSet(r'$hp += 5');
      expect(storage.getNumber('hp'), 15);
      storage.executeSet(r'$hp *= 2');
      expect(storage.getNumber('hp'), 30);
    });

    test('silently ignores malformed set commands', () {
      storage.setNumber('hp', 10);
      storage.executeSet('totally invalid');
      expect(storage.getNumber('hp'), 10);
    });
  });

  group('interpolate', () {
    late VariableStorage storage;
    setUp(() => storage = VariableStorage());

    test('fills inline expressions with their values', () {
      storage
        ..setString('item', 'radish')
        ..setNumber('count', 3);
      expect(
        storage.interpolate(r'{$count} {$item}es, {$count * 2} more'),
        '3 radishes, 6 more',
      );
      expect(storage.interpolate(r'A {$item}!'), 'A radish!');
      expect(storage.interpolate(r'{$count + 0.5}'), '3.5');
    });

    test('leaves plain text, escapes and malformed braces alone', () {
      expect(storage.interpolate('No braces here.'), 'No braces here.');
      expect(storage.interpolate(r'A \{literal}'), 'A {literal}');
      expect(storage.interpolate('Half {open'), 'Half {open');
      expect(storage.interpolate(r'{$x +}'), r'{$x +}');
    });
  });
}
