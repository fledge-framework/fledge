import 'package:flutter_test/flutter_test.dart';
import 'package:fledge_yarn/src/expression.dart';

void main() {
  final vars = <String, dynamic>{};
  final eval = ExpressionEvaluator((name) => vars[name]);

  setUp(vars.clear);

  group('literals', () {
    test('numbers', () {
      expect(eval.evaluate('42'), 42);
      expect(eval.evaluate('3.14'), 3.14);
      expect(eval.evaluate('.5'), 0.5);
    });

    test('booleans and null', () {
      expect(eval.evaluate('true'), true);
      expect(eval.evaluate('false'), false);
      expect(eval.evaluate('null'), isNull);
    });

    test('strings', () {
      expect(eval.evaluate('"hello"'), 'hello');
      expect(eval.evaluate("'hello'"), 'hello');
      expect(eval.evaluate(r'"a\nb"'), 'a\nb');
    });

    test('unknown barewords are strings', () {
      expect(eval.evaluate('foo'), 'foo');
    });
  });

  group('arithmetic precedence', () {
    test('multiplication before addition', () {
      expect(eval.evaluate('1 + 2 * 3'), 7);
      expect(eval.evaluate('2 * 3 + 1'), 7);
    });

    test('division before subtraction', () {
      expect(eval.evaluate('10 - 6 / 2'), 7);
    });

    test('left-associative addition and subtraction', () {
      expect(eval.evaluate('10 - 3 - 2'), 5);
      expect(eval.evaluate('1 + 2 + 3'), 6);
    });

    test('parentheses override precedence', () {
      expect(eval.evaluate('(1 + 2) * 3'), 9);
      expect(eval.evaluate('2 * (3 + 4)'), 14);
    });

    test('unary minus', () {
      expect(eval.evaluate('-5'), -5);
      expect(eval.evaluate('-(1 + 2)'), -3);
      expect(eval.evaluate('5 + -2'), 3);
    });

    test('modulo', () {
      expect(eval.evaluate('10 % 3'), 1);
    });
  });

  group('comparisons', () {
    test('numeric comparisons', () {
      expect(eval.evaluateBool('1 < 2'), true);
      expect(eval.evaluateBool('2 <= 2'), true);
      expect(eval.evaluateBool('3 > 4'), false);
      expect(eval.evaluateBool('5 == 5'), true);
      expect(eval.evaluateBool('5 != 6'), true);
    });

    test('comparison on arithmetic result respects precedence', () {
      // Regression for the documented P0: `1 + 2 * 3` must evaluate to 7,
      // not treat `+` and `*` left-to-right.
      expect(eval.evaluateBool('1 + 2 * 3 == 7'), true);
      expect(eval.evaluateBool('2 * 3 + 1 == 7'), true);
      expect(eval.evaluateBool('1 + 2 * 3 > 6'), true);
    });

    test('string comparisons', () {
      expect(eval.evaluateBool('"abc" == "abc"'), true);
      expect(eval.evaluateBool('"abc" != "abd"'), true);
      expect(eval.evaluateBool('"abc" < "abd"'), true);
    });
  });

  group('boolean logic precedence', () {
    test('not has higher precedence than and', () {
      expect(eval.evaluateBool('not false and true'), true);
      expect(eval.evaluateBool('not (false and true)'), true);
    });

    test('and has higher precedence than or', () {
      expect(eval.evaluateBool('true or false and false'), true);
      expect(eval.evaluateBool('false and true or true'), true);
      expect(eval.evaluateBool('false and (true or true)'), false);
    });

    test('short-circuit evaluation', () {
      // If `or` short-circuits, dividing by zero on the right is never reached.
      expect(eval.evaluateBool('true or 1 / 0 > 0'), true);
      expect(eval.evaluateBool('false and 1 / 0 > 0'), false);
    });
  });

  group('variables', () {
    test('lookup in arithmetic', () {
      vars['x'] = 10;
      vars['y'] = 3;
      expect(eval.evaluate(r'$x + $y * 2'), 16);
      expect(eval.evaluateBool(r'$x > $y'), true);
    });

    test('missing variable evaluates to null', () {
      expect(eval.evaluate(r'$missing'), isNull);
      expect(eval.evaluateBool(r'$missing == null'), true);
    });

    test('variable name with underscores and digits', () {
      vars['hp_2'] = 42;
      expect(eval.evaluate(r'$hp_2'), 42);
    });
  });

  group('string concatenation', () {
    test('"+" on strings concatenates', () {
      expect(eval.evaluate('"foo" + "bar"'), 'foobar');
    });

    test('"+" of string and number concatenates', () {
      vars['n'] = 3;
      expect(eval.evaluate(r'"count: " + $n'), 'count: 3');
    });
  });

  group('errors', () {
    test('unterminated string', () {
      expect(() => eval.evaluate('"hello'), throwsFormatException);
    });

    test('dangling operator', () {
      expect(() => eval.evaluate('1 +'), throwsFormatException);
    });

    test('mismatched parens', () {
      expect(() => eval.evaluate('(1 + 2'), throwsFormatException);
    });

    test('unexpected trailing token', () {
      expect(() => eval.evaluate('1 + 2 3'), throwsFormatException);
    });
  });

  group('executeSet', () {
    test('simple assignment', () {
      eval.executeSet(r'$x = 5', (name, value) => vars[name] = value);
      expect(vars['x'], 5);
    });

    test('assignment with expression rhs', () {
      vars['base'] = 10;
      eval.executeSet(
          r'$x = $base + 2 * 3', (name, value) => vars[name] = value);
      expect(vars['x'], 16);
    });

    test('compound += reads current value', () {
      vars['hp'] = 10;
      eval.executeSet(r'$hp += 5', (name, value) => vars[name] = value);
      expect(vars['hp'], 15);
    });

    test('compound -=, *=, /=', () {
      vars['x'] = 20;
      eval.executeSet(r'$x -= 5', (name, value) => vars[name] = value);
      expect(vars['x'], 15);
      eval.executeSet(r'$x *= 2', (name, value) => vars[name] = value);
      expect(vars['x'], 30);
      eval.executeSet(r'$x /= 3', (name, value) => vars[name] = value);
      expect(vars['x'], 10);
    });

    test('compound operator on uninitialized variable starts from 0', () {
      eval.executeSet(r'$x += 5', (name, value) => vars[name] = value);
      expect(vars['x'], 5);
    });

    test('missing operator throws', () {
      expect(
        () => eval.executeSet(r'$x', (name, value) => vars[name] = value),
        throwsFormatException,
      );
    });
  });
}
